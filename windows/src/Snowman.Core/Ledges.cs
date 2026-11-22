namespace Snowman.Core;

public enum LedgeType { Window, Taskbar, Ground }

/// <summary>What a ledge belongs to.</summary>
public readonly record struct LedgeKind(LedgeType Type, long Id)
{
    public static LedgeKind Ground => new(LedgeType.Ground, 0);
    public static LedgeKind Taskbar => new(LedgeType.Taskbar, 0);
    public static LedgeKind ForWindow(long id) => new(LedgeType.Window, id);
    public bool IsWindow => Type == LedgeType.Window;
    public override string ToString() => Type switch
    {
        LedgeType.Window => $"window({Id})",
        LedgeType.Taskbar => "taskbar",
        _ => "ground",
    };
}

/// <summary>One top-level window as reported by the OS (physical pixels, top-left origin).</summary>
public sealed record RawWindow(long Id, string ClassName, RectD Bounds, int OwnerPid);

public static class WindowFilter
{
    private static readonly HashSet<string> ExcludedClasses = new(StringComparer.Ordinal)
    {
        "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW", "#32768", "tooltips_class32",
        "NotifyIconOverflowWindow", "TopLevelWindowForOverflowXamlIsland", "XamlExplorerHostIslandWindow",
    };

    /// <summary>Keeps ordinary app windows snow can sit on, preserving front-to-back order.</summary>
    public static List<RawWindow> FilterSnowWindows(IEnumerable<RawWindow> raw, int ownPid) =>
        raw.Where(w => w.Bounds.Width >= 80 && w.Bounds.Height >= 40 && w.OwnerPid != ownPid
                       && !ExcludedClasses.Contains(w.ClassName)).ToList();
}

/// <summary>A surface snow can land on, in scene coordinates (origin bottom-left, y up).</summary>
public sealed class LedgeSpec
{
    public LedgeSpec(LedgeKind kind, double x0, double x1, double y, float maxHeight, float landProbability, IReadOnlyList<RectD> occluders)
    {
        Kind = kind; X0 = x0; X1 = x1; Y = y; MaxHeight = maxHeight; LandProbability = landProbability; Occluders = occluders;
    }

    public LedgeKind Kind { get; }
    public double X0 { get; }
    public double X1 { get; }
    /// <summary>The surface line (top edge of the window or taskbar, 0 for the ground).</summary>
    public double Y { get; }
    public float MaxHeight { get; }
    public float LandProbability { get; }
    /// <summary>Things drawn in front of this ledge (front windows, the taskbar).</summary>
    public IReadOnlyList<RectD> Occluders { get; }
    public double Width => X1 - X0;

    public bool SameAs(LedgeSpec? o) =>
        o is not null && Kind == o.Kind && X0 == o.X0 && X1 == o.X1 && Y == o.Y && MaxHeight == o.MaxHeight
        && LandProbability == o.LandProbability && Occluders.SequenceEqual(o.Occluders);
}

public static class LedgeTuning
{
    public const float WindowMaxHeight = 14;
    public const float TaskbarMaxHeight = 16;
    public const float GroundMaxHeight = 22;
    /// <summary>How far snow may rise into a reserved strip at the top of the screen.</summary>
    public const double TopAllowance = 10;
    public const float WindowLandProbability = 0.4f;
    public const float TaskbarLandProbability = 0.85f;
    public const float GroundLandProbability = 1.0f;
    public const double MinimumLedgeWidth = 40;
}

public static class Ledges
{
    /// <summary>Builds every ledge for one screen. Window frames are scene-space rects, front to back.</summary>
    public static List<LedgeSpec> Build(IReadOnlyList<(long Id, RectD Frame)> windowFrames, RectD? taskbar,
                                        double sceneWidth, double sceneHeight, double topReserved, bool includeWindows)
    {
        var result = new List<LedgeSpec>();
        double snowCeiling = sceneHeight - topReserved + LedgeTuning.TopAllowance;
        RectD[] taskbarOccluder = taskbar is RectD t ? new[] { t } : Array.Empty<RectD>();

        if (includeWindows)
        {
            for (int i = 0; i < windowFrames.Count; i++)
            {
                var f = windowFrames[i].Frame;
                double x0 = Math.Max(f.MinX, 0), x1 = Math.Min(f.MaxX, sceneWidth), y = f.MaxY;
                if (x1 - x0 < LedgeTuning.MinimumLedgeWidth || y <= 4 || y >= sceneHeight - 0.5) continue;
                float maxHeight = (float)Math.Min(LedgeTuning.WindowMaxHeight, snowCeiling - y);
                if (maxHeight <= 1) continue;
                var occ = new List<RectD>(i + taskbarOccluder.Length);
                for (int k = 0; k < i; k++) occ.Add(windowFrames[k].Frame);
                occ.AddRange(taskbarOccluder);
                result.Add(new LedgeSpec(LedgeKind.ForWindow(windowFrames[i].Id), x0, x1, y, maxHeight,
                                         LedgeTuning.WindowLandProbability, occ));
            }
        }

        if (taskbar is RectD tb)
        {
            double x0 = Math.Max(tb.MinX, 0), x1 = Math.Min(tb.MaxX, sceneWidth);
            if (x1 - x0 >= LedgeTuning.MinimumLedgeWidth && tb.MaxY < sceneHeight - 0.5)
            {
                result.Add(new LedgeSpec(LedgeKind.Taskbar, x0, x1, tb.MaxY, LedgeTuning.TaskbarMaxHeight,
                                         LedgeTuning.TaskbarLandProbability, Array.Empty<RectD>()));
            }
        }

        result.Add(new LedgeSpec(LedgeKind.Ground, 0, sceneWidth, 0, LedgeTuning.GroundMaxHeight,
                                 LedgeTuning.GroundLandProbability, taskbarOccluder));
        return result;
    }

    public static Visibility VisibilityOf(LedgeSpec spec, int columnCount)
    {
        var hidden = new bool[columnCount];
        var ceiling = new float[columnCount];
        Array.Fill(ceiling, float.PositiveInfinity);
        if (spec.Occluders.Count == 0) return new Visibility(hidden, ceiling);
        for (int c = 0; c < columnCount; c++)
        {
            double x = spec.X0 + (c + 0.5) * SnowPile.ColumnWidth;
            foreach (var o in spec.Occluders)
            {
                if (x < o.MinX || x >= o.MaxX) continue;
                if (spec.Y >= o.MinY && spec.Y <= o.MaxY) { hidden[c] = true; break; }
                if (o.MinY > spec.Y) ceiling[c] = Math.Min(ceiling[c], (float)(o.MinY - spec.Y));
            }
        }
        return new Visibility(hidden, ceiling);
    }
}

/// <summary>Per-column visibility of a ledge's snow.</summary>
public sealed class Visibility
{
    public Visibility(bool[] hidden, float[] ceiling) { Hidden = hidden; Ceiling = ceiling; }

    /// <summary>The ledge itself is covered by something in front.</summary>
    public bool[] Hidden { get; }
    /// <summary>Highest visible snow height before something in front covers it.</summary>
    public float[] Ceiling { get; }

    public float VisibleHeight(int c, float height)
    {
        if (c < 0 || c >= Hidden.Length || Hidden[c]) return 0;
        return Math.Min(height, Ceiling[c]);
    }
}
