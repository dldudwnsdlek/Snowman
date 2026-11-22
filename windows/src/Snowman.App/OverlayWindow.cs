using System;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using Snowman.App.Scene;
using Snowman.Core;

namespace Snowman.App;

/// <summary>Draws one scene.</summary>
internal sealed class SceneView : FrameworkElement
{
    public SnowScene? Scene { get; set; }

    protected override void OnRender(DrawingContext dc) => Scene?.Render(dc);
}

/// <summary>Transparent, click-through, always-on-top window covering one monitor.</summary>
internal sealed class OverlayWindow : Window
{
    private bool _clickThrough = true;

    public OverlayWindow(System.Drawing.Rectangle monitorBounds, bool primary)
    {
        MonitorBounds = monitorBounds;
        IsPrimary = primary;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false;
        Topmost = true;
        ShowActivated = false;
        ResizeMode = ResizeMode.NoResize;
        Focusable = false;
        WindowStartupLocation = WindowStartupLocation.Manual;
        Left = monitorBounds.Left;
        Top = monitorBounds.Top;
        Width = Math.Max(1, monitorBounds.Width);
        Height = Math.Max(1, monitorBounds.Height);
        Title = "Snowman overlay";
        Content = View;
        SourceInitialized += (_, _) => OnSourceInitialized();
        DpiChanged += (_, _) => UpdateScale();
        View.MouseLeftButtonDown += (_, e) =>
        {
            if (Scene is null) return;
            var p = e.GetPosition(View);
            Scene.MouseDown(new PointD(p.X, SceneHeight - p.Y), e.Timestamp / 1000.0);
            View.CaptureMouse();
            e.Handled = true;
        };
        View.MouseMove += (_, e) =>
        {
            if (Scene is null || !View.IsMouseCaptured) return;
            var p = e.GetPosition(View);
            Scene.MouseDragged(new PointD(p.X, SceneHeight - p.Y), e.Timestamp / 1000.0);
        };
        View.MouseLeftButtonUp += (_, e) =>
        {
            if (Scene is null) return;
            var p = e.GetPosition(View);
            Scene.MouseUp(new PointD(p.X, SceneHeight - p.Y), e.Timestamp / 1000.0);
            View.ReleaseMouseCapture();
            e.Handled = true;
        };
        View.LostMouseCapture += (_, _) => Scene?.CancelDrag();
    }

    public SceneView View { get; } = new();
    public SnowScene? Scene { get; private set; }
    public System.Drawing.Rectangle MonitorBounds { get; }
    public bool IsPrimary { get; }
    public IntPtr Handle { get; private set; }
    /// <summary>Physical pixels per WPF unit on this monitor.</summary>
    public double Scale { get; private set; } = 1;
    public double SceneWidth => MonitorBounds.Width / Scale;
    public double SceneHeight => MonitorBounds.Height / Scale;

    public event Action<OverlayWindow>? SceneReady;

    private void OnSourceInitialized()
    {
        Handle = new WindowInteropHelper(this).Handle;
        long ex = Native.ExStyle(Handle);
        ex |= Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE | Native.WS_EX_TRANSPARENT | Native.WS_EX_LAYERED;
        ex &= ~Native.WS_EX_APPWINDOW;
        Native.SetWindowLongPtr(Handle, Native.GWL_EXSTYLE, new IntPtr(ex));
        PlaceOnMonitor();
        UpdateScale();
        Scene = new SnowScene(SceneWidth, SceneHeight);
        View.Scene = Scene;
        SceneReady?.Invoke(this);
    }

    public void PlaceOnMonitor() =>
        Native.SetWindowPos(Handle, Native.HWND_TOPMOST, MonitorBounds.Left, MonitorBounds.Top, MonitorBounds.Width, MonitorBounds.Height,
                            Native.SWP_NOACTIVATE | Native.SWP_NOOWNERZORDER);

    private void UpdateScale()
    {
        if (Handle == IntPtr.Zero) return;
        uint dpi = Native.GetDpiForWindow(Handle);
        Scale = dpi > 0 ? dpi / 96.0 : 1;
        Scene?.Resize(SceneWidth, SceneHeight);
    }

    public void ReassertTopmost()
    {
        if (Handle == IntPtr.Zero) return;
        Native.SetWindowPos(Handle, Native.HWND_TOPMOST, 0, 0, 0, 0,
                            Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE | Native.SWP_NOOWNERZORDER);
    }

    /// <summary>Clicks pass through unless the scene wants them (hovering snow, a snowball or a snowman).</summary>
    public void SetClickThrough(bool on)
    {
        if (Handle == IntPtr.Zero || _clickThrough == on) return;
        _clickThrough = on;
        long ex = Native.ExStyle(Handle);
        ex = on ? ex | Native.WS_EX_TRANSPARENT : ex & ~Native.WS_EX_TRANSPARENT;
        Native.SetWindowLongPtr(Handle, Native.GWL_EXSTYLE, new IntPtr(ex));
    }

    /// <summary>Cursor (physical pixels) in this scene, or null when it is on another monitor.</summary>
    public PointD? ToScene(Native.POINT p)
    {
        var b = MonitorBounds;
        if (p.X < b.Left || p.X >= b.Right || p.Y < b.Top || p.Y >= b.Bottom) return null;
        return new PointD((p.X - b.Left) / Scale, SceneHeight - (p.Y - b.Top) / Scale);
    }

    /// <summary>Physical rect (top-left origin) to scene rect (bottom-left origin, WPF units).</summary>
    public RectD ToScene(RectD r)
    {
        var b = MonitorBounds;
        return new RectD((r.X - b.Left) / Scale, SceneHeight - (r.Y - b.Top + r.Height) / Scale, r.Width / Scale, r.Height / Scale);
    }

    public bool Overlaps(RectD r)
    {
        var b = MonitorBounds;
        return r.X < b.Right && r.X + r.Width > b.Left && r.Y < b.Bottom && r.Y + r.Height > b.Top;
    }

    /// <summary>The taskbar on this monitor when it is showing at the bottom edge.</summary>
    public RectD? VisibleTaskbar(System.Collections.Generic.IEnumerable<RectD> taskbars)
    {
        var b = MonitorBounds;
        foreach (var t in taskbars)
        {
            double cx = t.X + t.Width / 2, cy = t.Y + t.Height / 2;
            if (cx < b.Left || cx >= b.Right || cy < b.Top || cy >= b.Bottom + t.Height) continue;
            double top = Math.Max(t.Y, b.Top), bottom = Math.Min(t.Y + t.Height, b.Bottom);
            bool showing = bottom - top >= 8;
            bool atBottom = t.Y + t.Height >= b.Bottom - 2 && t.Width >= b.Width * 0.5;
            if (showing && atBottom) return ToScene(t);
        }
        return null;
    }
}
