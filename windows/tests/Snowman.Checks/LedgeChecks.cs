using Snowman.Core;
using static Snowman.Checks.Harness;

namespace Snowman.Checks;

internal static class LedgeChecks
{
    private const double W = 1512, H = 982;

    private static List<LedgeSpec> Specs((long, RectD)[] windows, RectD? taskbar = null, bool includeWindows = true, double topReserved = 33) =>
        Ledges.Build(windows.Select(w => (w.Item1, w.Item2)).ToList(), taskbar, W, H, topReserved, includeWindows);

    private static int Columns(LedgeSpec s) => new SnowPile(s.Width, s.MaxHeight).ColumnCount;

    public static void Run()
    {
        {
            var raw = new[]
            {
                new RawWindow(1, "Chrome_WidgetWin_1", new RectD(0, 33, 800, 600), 100),
                new RawWindow(2, "Shell_TrayWnd", new RectD(0, 0, 1512, 48), 101),
                new RawWindow(3, "HwndWrapper", new RectD(0, 0, 1512, 982), 999),
                new RawWindow(4, "Tiny", new RectD(10, 10, 50, 20), 102),
                new RawWindow(5, "Progman", new RectD(0, 0, 1512, 982), 103),
                new RawWindow(8, "Notepad", new RectD(462, 228, 380, 640), 105),
            };
            var kept = WindowFilter.FilterSnowWindows(raw, 999);
            Check("filterKeepsOnlyNormalWindows", kept.Select(k => k.Id).SequenceEqual(new long[] { 1, 8 }),
                  string.Join(",", kept.Select(k => k.Id)));
        }
        {
            var f = new RectD(0, 0, 1512, 949);
            var back = Specs(new[] { (1L, f), (2L, f) }).FirstOrDefault(s => s.Kind == LedgeKind.ForWindow(2));
            Check("frontWindowHidesBackLedge.exists", back is not null);
            if (back is not null) Check("frontWindowHidesBackLedge", Ledges.VisibilityOf(back, Columns(back)).Hidden.All(h => h));
        }
        {
            var back = new RectD(0, 100, 600, 400);
            var front = new RectD(0, 505, 300, 195);
            var s = Specs(new[] { (1L, front), (2L, back) }).First(x => x.Kind == LedgeKind.ForWindow(2));
            var vis = Ledges.VisibilityOf(s, Columns(s));
            Close("occluderAboveLimitsCeiling.covered", vis.Ceiling[10], 5, 0.001);
            Check("occluderAboveLimitsCeiling.free", float.IsPositiveInfinity(vis.Ceiling[200]));
            Check("occluderAboveLimitsCeiling.notHidden", !vis.Hidden[10]);
        }
        {
            var s = Specs(new[] { (1L, new RectD(0, 0, 1512, 949)) }).FirstOrDefault(x => x.Kind == LedgeKind.ForWindow(1));
            Check("windowUnderReservedTopCapped", s?.MaxHeight == 10, $"got {s?.MaxHeight}");
            var full = Specs(new[] { (1L, new RectD(0, 0, 1512, 982)) }, topReserved: 0);
            Check("fullScreenWindowHasNoLedge", !full.Any(x => x.Kind.IsWindow));
        }
        {
            var all = Specs(Array.Empty<(long, RectD)>());
            Check("groundAlwaysPresent", all.Count == 1 && all[0].Kind == LedgeKind.Ground && all[0].MaxHeight == 22 && all[0].LandProbability == 1);
        }
        {
            var taskbar = new RectD(0, 0, 1512, 48);
            var all = Specs(Array.Empty<(long, RectD)>(), taskbar);
            var t = all.FirstOrDefault(x => x.Kind == LedgeKind.Taskbar);
            Check("taskbarLedge.geometry", t is not null && t.X0 == 0 && t.X1 == 1512 && t.Y == 48 && t.MaxHeight == 16 && t.LandProbability == 0.85f);
            var g = all.First(x => x.Kind == LedgeKind.Ground);
            var vis = Ledges.VisibilityOf(g, Columns(g));
            Check("taskbarHidesGround", vis.Hidden.All(h => h));
        }
        {
            var all = Specs(new[] { (1L, new RectD(100, 200, 400, 300)) }, includeWindows: false);
            Check("windowsExcludedWhenToggledOff", !all.Any(x => x.Kind.IsWindow));
        }
        var w7 = new RectD(100, 200, 400, 300);
        {
            var store = new PileStore();
            store.Sync(Specs(new[] { (7L, w7) }), 0, 0);
            store.Piles[LedgeKind.ForWindow(7)].Add(50, 10);
            var r = store.Sync(Specs(Array.Empty<(long, RectD)>()), 10, 0);
            Check("pileStoreDropsClosedWindow.dropped", r.Dropped.Any(d => d.Spec.Kind == LedgeKind.ForWindow(7) && d.Pile.TotalArea > 9));
            Check("pileStoreDropsClosedWindow.removed", !store.Piles.ContainsKey(LedgeKind.ForWindow(7)));
        }
        {
            var store = new PileStore();
            store.Sync(Specs(new[] { (7L, w7) }), 0, 0);
            store.Piles[LedgeKind.ForWindow(7)].Add(50, 10);
            var r = store.Sync(Specs(Array.Empty<(long, RectD)>()), 10, 11);
            Check("pileStoreStashesDuringGrace.nothingDropped", r.Dropped.Count == 0);
            store.Sync(Specs(new[] { (7L, w7) }), 20, 0);
            Close("pileStoreStashesDuringGrace.restored", store.Piles[LedgeKind.ForWindow(7)].TotalArea, 10, 0.01);
        }
        {
            var store = new PileStore();
            store.Sync(Specs(new[] { (7L, w7) }), 0, 0);
            store.Piles[LedgeKind.ForWindow(7)].Add(50, 10);
            var r = store.Sync(Specs(Array.Empty<(long, RectD)>()), 10, 0, k => k == LedgeKind.ForWindow(7));
            Check("pileStoreKeepsCloakedWindow", r.Dropped.Count == 0 && store.Stash.ContainsKey(LedgeKind.ForWindow(7)));
        }
        {
            var taskbar = new RectD(0, 0, 1512, 48);
            var store = new PileStore();
            store.Sync(Specs(Array.Empty<(long, RectD)>(), taskbar), 0, 0);
            store.Piles[LedgeKind.Taskbar].Add(100, 10);
            var r = store.Sync(Specs(Array.Empty<(long, RectD)>()), 10, 0);
            Check("taskbarIsAlwaysStashed.nothingDropped", r.Dropped.Count == 0);
            store.Sync(Specs(Array.Empty<(long, RectD)>(), taskbar), 20, 0);
            Close("taskbarIsAlwaysStashed.restored", store.Piles[LedgeKind.Taskbar].TotalArea, 10, 0.01);
        }
        {
            var store = new PileStore();
            store.Sync(Specs(new[] { (7L, w7) }), 0, 0);
            var r = store.Sync(Specs(new[] { (7L, w7.Offset(30, -10)) }), 1, 0);
            var m = r.Moved.FirstOrDefault(x => x.Kind == LedgeKind.ForWindow(7));
            Check("movedWindowReportsDelta", m.Dx == 30 && m.Dy == -10, $"got {m}");
        }
    }
}
