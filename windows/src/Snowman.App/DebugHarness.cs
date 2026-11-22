using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Snowman.Core;

namespace Snowman.App;

/// <summary>
/// Developer aid used by CI: with SNOWMAN_DEBUG_DIR set, commands from SNOWMAN_DEBUG_SCRIPT (run at start)
/// or from &lt;dir&gt;/cmd.txt drive the app, and "snap"/"screenshot" write images plus a text report there.
/// </summary>
internal sealed class DebugHarness
{
    private readonly SnowController _c;
    private readonly string _dir;
    private readonly DispatcherTimer _timer;

    private DebugHarness(SnowController c, string dir)
    {
        _c = c;
        _dir = dir;
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        _timer.Tick += (_, _) => PollCommands();
        _timer.Start();
        string? script = Environment.GetEnvironmentVariable("SNOWMAN_DEBUG_SCRIPT");
        if (!string.IsNullOrEmpty(script) && File.Exists(script)) Run(File.ReadAllLines(script));
    }

    public static DebugHarness? TryCreate(SnowController c)
    {
        string? dir = Environment.GetEnvironmentVariable("SNOWMAN_DEBUG_DIR");
        if (string.IsNullOrEmpty(dir)) return null;
        Directory.CreateDirectory(dir);
        return new DebugHarness(c, dir);
    }

    private void PollCommands()
    {
        string path = Path.Combine(_dir, "cmd.txt");
        if (!File.Exists(path)) return;
        string[] lines;
        try
        {
            lines = File.ReadAllLines(path);
            File.Delete(path);
        }
        catch
        {
            return;
        }
        Run(lines);
    }

    private void Log(string text) => File.AppendAllText(Path.Combine(_dir, "harness.log"), $"{_c.Now:0.00} {text}{Environment.NewLine}");

    private async void Run(IEnumerable<string> lines)
    {
        foreach (var raw in lines)
        {
            string line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            double Num(int i) => parts.Length > i ? double.Parse(parts[i], CultureInfo.InvariantCulture) : 0;
            string arg = parts.Length > 1 ? parts[1] : "";
            var scene = _c.Overlays.FirstOrDefault(o => o.IsPrimary)?.Scene ?? _c.Overlays.FirstOrDefault()?.Scene;
            try
            {
                Log(line);
                switch (parts[0])
                {
                    case "wait": await Task.Delay(TimeSpan.FromSeconds(Num(1))); break;
                    case "snap": Snap(arg); break;
                    case "screenshot": Screenshot(arg); break;
                    case "spawn": _c.SpawnSnowman(SnowmanStyleInfo.All.Cast<SnowmanStyle?>().FirstOrDefault(s => s.ToString()!.Equals(arg, StringComparison.OrdinalIgnoreCase))); break;
                    case "plow": _c.CallPlow(); break;
                    case "clear": _c.ClearSnow(); break;
                    case "clearmen": _c.ClearSnowmen(); break;
                    case "amount": if (SnowAmountInfo.FromKey(arg) is SnowAmount a) _c.SetAmount(a); break;
                    case "pause": _c.SetSnowing(arg != "on"); break;
                    case "windows": _c.SetAccumulateOnWindows(arg == "on"); break;
                    case "fill": scene?.DebugFill(Num(1)); break;
                    case "roll": scene?.DebugRoll(Num(1), Num(2), parts.Length > 4 ? new PointD(Num(3), Num(4)) : null); break;
                    case "throw": scene?.DebugThrow(Num(1), Num(2)); break;
                    case "wallpaper": _c.Wallpapers.Apply((int)Num(1)); break;
                    case "restore": _c.Wallpapers.RestoreOriginal(); break;
                    case "help": await RenderHelp(); break;
                    case "notepad": await OpenNotepad((int)Num(1), (int)Num(2), (int)Num(3), (int)Num(4)); break;
                    case "close":
                        foreach (var p in Process.GetProcessesByName(arg)) p.CloseMainWindow();
                        break;
                    case "quit": _c.Quit(); return;
                }
            }
            catch (Exception e)
            {
                Log("ERROR " + e);
            }
        }
    }

    private static void SavePng(BitmapSource bmp, string path)
    {
        var enc = new PngBitmapEncoder();
        enc.Frames.Add(BitmapFrame.Create(bmp));
        using var fs = File.Create(path);
        enc.Save(fs);
    }

    /// <summary>Each overlay drawn over outlines of the tracked windows, plus a text report.</summary>
    private void Snap(string name)
    {
        var report = new StringBuilder();
        report.AppendLine($"== snap {name} at {_c.Now:0.00}s");
        var snap = _c.LastSnapshot;
        foreach (var w in snap?.Windows ?? new List<RawWindow>()) report.AppendLine($"window {w.Id} {w.ClassName} {w.Bounds}");
        foreach (var t in snap?.Taskbars ?? new List<RectD>()) report.AppendLine($"taskbar {t}");
        for (int i = 0; i < _c.Overlays.Count; i++)
        {
            var o = _c.Overlays[i];
            if (o.Scene is null) continue;
            report.AppendLine($"[overlay {i}] monitor {o.MonitorBounds} scale {o.Scale}");
            report.Append(o.Scene.DebugReport());
            int w = Math.Max(1, (int)Math.Ceiling(o.View.ActualWidth)), h = Math.Max(1, (int)Math.Ceiling(o.View.ActualHeight));
            var overlay = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
            overlay.Render(o.View);
            var dv = new DrawingVisual();
            using (var dc = dv.RenderOpen())
            {
                dc.DrawRectangle(new SolidColorBrush(Color.FromRgb(0x2B, 0x34, 0x45)), null, new Rect(0, 0, w, h));
                var fill = new SolidColorBrush(Color.FromArgb(220, 0x5A, 0x64, 0x78));
                var title = new SolidColorBrush(Color.FromRgb(0x73, 0x7D, 0x92));
                var edge = new Pen(new SolidColorBrush(Color.FromRgb(0xAA, 0xB4, 0xC8)), 1);
                foreach (var win in (snap?.Windows ?? new List<RawWindow>()).AsEnumerable().Reverse())
                {
                    if (!o.Overlaps(win.Bounds)) continue;
                    var r = o.ToScene(win.Bounds);
                    var rect = new Rect(r.X, o.SceneHeight - r.MaxY, r.Width, r.Height);
                    dc.DrawRectangle(fill, edge, rect);
                    dc.DrawRectangle(title, null, new Rect(rect.X, rect.Y, rect.Width, Math.Min(28, rect.Height)));
                }
                if (o.VisibleTaskbar(snap?.Taskbars ?? new List<RectD>()) is RectD tb)
                    dc.DrawRectangle(new SolidColorBrush(Color.FromArgb(160, 0x8F, 0xA3, 0xC7)), edge, new Rect(tb.X, o.SceneHeight - tb.MaxY, tb.Width, tb.Height));
                dc.DrawImage(overlay, new Rect(0, 0, w, h));
            }
            var final = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
            final.Render(dv);
            SavePng(final, Path.Combine(_dir, $"snap-{name}-{i}.png"));
        }
        File.AppendAllText(Path.Combine(_dir, "report.txt"), report.ToString());
    }

    /// <summary>A real screenshot of the virtual screen (layered windows included).</summary>
    private void Screenshot(string name)
    {
        var b = System.Windows.Forms.SystemInformation.VirtualScreen;
        using var bmp = new System.Drawing.Bitmap(b.Width, b.Height);
        using (var g = System.Drawing.Graphics.FromImage(bmp))
        {
            g.CopyFromScreen(b.Left, b.Top, 0, 0, b.Size, System.Drawing.CopyPixelOperation.SourceCopy | System.Drawing.CopyPixelOperation.CaptureBlt);
        }
        bmp.Save(Path.Combine(_dir, $"screen-{name}.png"), System.Drawing.Imaging.ImageFormat.Png);
    }

    private async Task RenderHelp()
    {
        HelpWindow.ShowHelp();
        await Task.Delay(800);
        if (HelpWindow.Current?.Content is not FrameworkElement root) return;
        int w = (int)Math.Ceiling(root.ActualWidth), h = (int)Math.Ceiling(root.ActualHeight);
        var rtb = new RenderTargetBitmap(Math.Max(1, w), Math.Max(1, h), 96, 96, PixelFormats.Pbgra32);
        var dv = new DrawingVisual();
        using (var dc = dv.RenderOpen())
        {
            dc.DrawRectangle(Brushes.White, null, new Rect(0, 0, w, h));
            dc.DrawRectangle(new VisualBrush(root), null, new Rect(0, 0, w, h));
        }
        rtb.Render(dv);
        SavePng(rtb, Path.Combine(_dir, "help.png"));
        HelpWindow.Current?.Close();
    }

    private static async Task OpenNotepad(int x, int y, int w, int h)
    {
        var p = Process.Start(new ProcessStartInfo("notepad.exe") { UseShellExecute = true });
        if (p is null) return;
        for (int i = 0; i < 60; i++)
        {
            await Task.Delay(100);
            p.Refresh();
            if (p.MainWindowHandle != IntPtr.Zero) break;
        }
        if (p.MainWindowHandle != IntPtr.Zero) Native.MoveWindow(p.MainWindowHandle, x, y, w, h, true);
    }
}
