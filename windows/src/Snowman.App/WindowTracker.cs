using System;
using System.Collections.Generic;
using System.Linq;
using Snowman.Core;

namespace Snowman.App;

/// <summary>Everything the overlays need to know about other windows, in physical pixels (top-left origin).</summary>
internal sealed class TrackerSnapshot
{
    /// <summary>Ordinary windows, front to back.</summary>
    public List<RawWindow> Windows { get; } = new();
    public List<RectD> Taskbars { get; } = new();

    public bool SameAs(TrackerSnapshot? o) =>
        o is not null
        && Windows.Count == o.Windows.Count
        && Windows.Zip(o.Windows).All(p => p.First.Id == p.Second.Id && p.First.Bounds == p.Second.Bounds)
        && Taskbars.SequenceEqual(o.Taskbars);
}

/// <summary>Reads where every window and the taskbar are.</summary>
internal sealed class WindowTracker
{
    private readonly int _ownPid = Environment.ProcessId;

    public TrackerSnapshot Snapshot()
    {
        var snap = new TrackerSnapshot();
        var raw = new List<RawWindow>();
        Native.EnumWindows((h, _) =>
        {
            try
            {
                Inspect(h, raw, snap.Taskbars);
            }
            catch
            {
                // a window can vanish while we look at it
            }
            return true;
        }, IntPtr.Zero);
        snap.Windows.AddRange(WindowFilter.FilterSnowWindows(raw, _ownPid));
        return snap;
    }

    private static void Inspect(IntPtr h, List<RawWindow> raw, List<RectD> taskbars)
    {
        if (!Native.IsWindowVisible(h)) return;
        string cls = Native.ClassName(h);
        if (cls is "Shell_TrayWnd" or "Shell_SecondaryTrayWnd")
        {
            if (Native.Bounds(h) is Native.RECT tb) taskbars.Add(ToRect(tb));
            return;
        }
        if (Native.IsIconic(h) || Native.IsCloaked(h)) return;
        long ex = Native.ExStyle(h);
        long st = Native.Style(h);
        if ((ex & Native.WS_EX_TRANSPARENT) != 0) return;
        bool appWindow = (ex & Native.WS_EX_APPWINDOW) != 0;
        if ((ex & Native.WS_EX_TOOLWINDOW) != 0 && !appWindow) return;
        if ((ex & Native.WS_EX_NOACTIVATE) != 0 && !appWindow) return;
        bool framed = (st & Native.WS_CAPTION) == Native.WS_CAPTION || (st & Native.WS_THICKFRAME) != 0 || appWindow;
        if (!framed) return;
        if (Native.Bounds(h) is not Native.RECT r) return;
        Native.GetWindowThreadProcessId(h, out uint pid);
        raw.Add(new RawWindow(h.ToInt64(), cls, ToRect(r), (int)pid));
    }

    private static RectD ToRect(Native.RECT r) => new(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);

    /// <summary>A vanished window that still exists but is cloaked lives on another virtual desktop: keep its snow.</summary>
    public static bool IsAwayButAlive(LedgeKind kind)
    {
        if (!kind.IsWindow) return false;
        var h = new IntPtr(kind.Id);
        return Native.IsWindow(h) && !Native.IsIconic(h) && Native.IsCloaked(h);
    }
}
