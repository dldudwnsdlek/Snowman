using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using Snowman.Core;

namespace Snowman.App;

/// <summary>Owns the overlays, polls window positions and drives every frame.</summary>
internal sealed class SnowController
{
    private readonly Application _app;
    private readonly WindowTracker _tracker = new();
    private readonly Stopwatch _clock = Stopwatch.StartNew();
    private TrayMenu? _tray;
    private DebugHarness? _debug;
    private double _lastPoll, _fastUntil, _lastTopmost, _lastFrame;
    private TimeSpan _lastRenderingTime;
    private bool _rebuildPending;

    public SnowController(Application app)
    {
        _app = app;
        Settings = Settings.Load();
        Wallpapers = new WallpaperManager(Settings);
    }

    public Settings Settings { get; }
    public WallpaperManager Wallpapers { get; }
    public List<OverlayWindow> Overlays { get; } = new();
    public TrackerSnapshot? LastSnapshot { get; private set; }
    public double Now => _clock.Elapsed.TotalSeconds;

    public void Start()
    {
        Sound.Enabled = Settings.SoundOn;
        BuildOverlays();
        _tray = new TrayMenu(this);
        CompositionTarget.Rendering += OnFrame;
        Microsoft.Win32.SystemEvents.DisplaySettingsChanged += (_, _) => _app.Dispatcher.BeginInvoke(new Action(RequestRebuild));
        Wallpapers.PrerenderAll();
        _debug = DebugHarness.TryCreate(this);
    }

    public void Stop()
    {
        CompositionTarget.Rendering -= OnFrame;
        _tray?.Dispose();
    }

    public void Quit() => _app.Shutdown();

    private void RequestRebuild()
    {
        if (_rebuildPending) return;
        _rebuildPending = true;
        _app.Dispatcher.BeginInvoke(new Action(() =>
        {
            _rebuildPending = false;
            foreach (var o in Overlays) o.Close();
            Overlays.Clear();
            BuildOverlays();
        }), System.Windows.Threading.DispatcherPriority.Background);
    }

    private void BuildOverlays()
    {
        foreach (var screen in System.Windows.Forms.Screen.AllScreens)
        {
            var o = new OverlayWindow(screen.Bounds, screen.Primary);
            o.SceneReady += ConfigureScene;
            o.Show();
            Overlays.Add(o);
        }
        LastSnapshot = null;
    }

    private void ConfigureScene(OverlayWindow o)
    {
        if (o.Scene is null) return;
        o.Scene.Amount = Settings.AmountValue;
        o.Scene.Snowing = !Settings.Paused;
        o.Scene.AccumulateOnWindows = Settings.AccumulateOnWindows;
        o.Scene.KeepAway = WindowTracker.IsAwayButAlive;
        o.Scene.NeedsApply = true;
    }

    private void OnFrame(object? sender, EventArgs e)
    {
        if (e is RenderingEventArgs args)
        {
            if (args.RenderingTime == _lastRenderingTime) return;
            _lastRenderingTime = args.RenderingTime;
        }
        double now = Now;
        double dt = _lastFrame == 0 ? 1.0 / 60 : Math.Min(0.05, now - _lastFrame);
        _lastFrame = now;
        Native.GetCursorPos(out var cursor);
        bool nearBottom = Overlays.Any(o => cursor.X >= o.MonitorBounds.Left && cursor.X < o.MonitorBounds.Right && cursor.Y >= o.MonitorBounds.Bottom - 8);
        bool fast = Native.LeftButtonDown() || nearBottom || now < _fastUntil;
        bool needsApply = Overlays.Any(o => o.Scene?.NeedsApply == true);
        if (needsApply || now - _lastPoll >= (fast ? 1.0 / 60 : 1.0 / 8))
        {
            _lastPoll = now;
            var snap = _tracker.Snapshot();
            if (!snap.SameAs(LastSnapshot) || needsApply)
            {
                if (LastSnapshot is not null) _fastUntil = now + 1.0;
                LastSnapshot = snap;
                foreach (var o in Overlays) ApplySnapshot(o, snap, now);
            }
        }
        foreach (var o in Overlays)
        {
            if (o.Scene is null) continue;
            o.Scene.Mouse = o.ToScene(cursor);
            o.Scene.Update(dt, now);
            o.View.InvalidateVisual();
            o.SetClickThrough(!o.Scene.WantsMouse);
        }
        if (now - _lastTopmost > 0.5)
        {
            _lastTopmost = now;
            foreach (var o in Overlays) o.ReassertTopmost();
        }
    }

    private static void ApplySnapshot(OverlayWindow o, TrackerSnapshot snap, double now)
    {
        if (o.Scene is null) return;
        var windows = new List<(long, RectD)>();
        foreach (var w in snap.Windows)
            if (o.Overlaps(w.Bounds)) windows.Add((w.Id, o.ToScene(w.Bounds)));
        o.Scene.Apply(windows, o.VisibleTaskbar(snap.Taskbars), now);
    }

    // ---- Commands from the tray menu ----

    private IEnumerable<Scene.SnowScene> Scenes => Overlays.Where(o => o.Scene is not null).Select(o => o.Scene!);

    public void SetSnowing(bool on)
    {
        Settings.Paused = !on;
        Settings.Save();
        foreach (var s in Scenes) s.Snowing = on;
    }

    public void SetAmount(SnowAmount amount)
    {
        Settings.AmountValue = amount;
        Settings.Paused = false;
        Settings.Save();
        foreach (var s in Scenes)
        {
            s.Amount = amount;
            s.Snowing = true;
        }
    }

    public void SetAccumulateOnWindows(bool on)
    {
        Settings.AccumulateOnWindows = on;
        Settings.Save();
        foreach (var s in Scenes)
        {
            s.AccumulateOnWindows = on;
            s.NeedsApply = true;
        }
    }

    public void SetSound(bool on)
    {
        Settings.SoundOn = on;
        Settings.Save();
        Sound.Enabled = on;
    }

    public void ClearSnow()
    {
        foreach (var s in Scenes) s.ClearSnow(Now);
    }

    public void ClearSnowmen()
    {
        foreach (var s in Scenes) s.ClearSnowmen();
    }

    public void CallPlow()
    {
        foreach (var s in Scenes) s.CallPlow();
    }

    /// <summary>Builds a snowman on the monitor that has the cursor (or the primary monitor).</summary>
    public void SpawnSnowman(SnowmanStyle? style)
    {
        Native.GetCursorPos(out var cursor);
        var target = Overlays.FirstOrDefault(o => o.Scene is not null && o.ToScene(cursor) is not null)
                     ?? Overlays.FirstOrDefault(o => o.IsPrimary) ?? Overlays.FirstOrDefault();
        target?.Scene?.SpawnSnowman(style);
    }
}
