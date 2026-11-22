using Snowman.Core;
using static Snowman.Checks.Harness;

namespace Snowman.Checks;

internal static class PhysicsChecks
{
    private static (LedgeSpec Spec, SnowPile Pile, Visibility Vis) GroundPile(float height, double around, RectD? taskbar = null)
    {
        var g = Ledges.Build(new List<(long, RectD)>(), taskbar, 1512, 982, 0, true).First(s => s.Kind == LedgeKind.Ground);
        var p = new SnowPile(g.Width, g.MaxHeight);
        for (double x = around - 40; x <= around + 40; x += SnowPile.ColumnWidth) p.Add(x, height * (float)SnowPile.ColumnWidth);
        return (g, p, Ledges.VisibilityOf(g, p.ColumnCount));
    }

    public static void Run()
    {
        Check("snowAmountRates", SnowAmount.Light.FlakesPerSecond() == 15 && SnowAmount.Normal.FlakesPerSecond() == 45 && SnowAmount.Heavy.FlakesPerSecond() == 130);
        Check("snowAmountTitles", SnowAmountInfo.All.Select(a => a.Title()).SequenceEqual(new[] { "조금", "보통", "펑펑" }));
        Check("crossingDetected.cross", Physics.Crossed(10, 8, 9));
        Check("crossingDetected.above", !Physics.Crossed(10, 9.5, 9));
        Check("crossingDetected.fromSurface", Physics.Crossed(9, 8, 9));
        Check("crossingDetected.below", !Physics.Crossed(8, 7, 9));
        Close("radiusGrows", Physics.GrownRadius(6, 100), Math.Sqrt(36 + 150 / Math.PI), 0.001);
        Check("radiusCaps", Physics.GrownRadius(6, 1_000_000) == 56);
        Check("impact.soft", Physics.Impact(699) == ImpactLevel.Soft);
        Check("impact.crash", Physics.Impact(700) == ImpactLevel.Crash && Physics.Impact(2199) == ImpactLevel.Crash);
        Check("impact.shatter", Physics.Impact(2200) == ImpactLevel.Shatter);

        var bounds = new RectD(0, 0, 1512, 982);
        {
            var p = new PointD(5, 500); var v = new VectorD(-1000, 0);
            var hit = Physics.BounceOffWalls(ref p, ref v, 20, 30, bounds, 0.55);
            Check("bounce.left.side", hit?.Side == WallSide.Left && hit?.Speed == 1000);
            Close("bounce.left.vx", v.Dx, 550, 0.001);
            Check("bounce.left.clamped", p.X == 20);
        }
        {
            var p = new PointD(1500, 500); var v = new VectorD(800, 0);
            var hit = Physics.BounceOffWalls(ref p, ref v, 20, 30, bounds, 0.55);
            Check("bounce.right", hit?.Side == WallSide.Right && Math.Abs(v.Dx + 440) < 0.001 && p.X == 1492);
        }
        {
            var p = new PointD(700, 975); var v = new VectorD(0, 600);
            var hit = Physics.BounceOffWalls(ref p, ref v, 20, 30, bounds, 0.55);
            Check("bounce.top", hit?.Side == WallSide.Top && Math.Abs(v.Dy + 330) < 0.001 && p.Y == 952);
        }
        {
            var p = new PointD(700, 500); var v = new VectorD(300, 300);
            var hit = Physics.BounceOffWalls(ref p, ref v, 20, 30, bounds, 0.55);
            Check("bounce.none", hit is null && v.Dx == 300);
        }
        {
            var resting = new[] { (3, new PointD(500, 40), 30.0) };
            Check("stack.aligned", Physics.StackCandidate(new PointD(510, 90), 20, resting) == 3);
            Check("stack.offside", Physics.StackCandidate(new PointD(540, 90), 20, resting) is null);
            Check("stack.tooHigh", Physics.StackCandidate(new PointD(500, 120), 20, resting) is null);
        }
        {
            var bag = new StyleBag(7);
            var first = Enumerable.Range(0, 5).Select(_ => bag.Next()).ToHashSet();
            Check("styleBag.firstCycle", first.SetEquals(SnowmanStyleInfo.All));
            var second = Enumerable.Range(0, 5).Select(_ => bag.Next()).ToHashSet();
            Check("styleBag.secondCycle", second.SetEquals(SnowmanStyleInfo.All));
            Check("styleTitles", SnowmanStyleInfo.All.Select(s => s.Title()).SequenceEqual(new[] { "산타", "비니", "신사", "귀마개", "요정" }));
        }
        var none = Array.Empty<(int, RectD)>();
        var noBalls = Array.Empty<(int, PointD, double)>();
        {
            var thin = GroundPile(2, 100);
            Check("hit.thinSnow", Interaction.HitTest(new PointD(100, 2), none, noBalls, new[] { thin }) is null);
            var deep = GroundPile(6, 100);
            Check("hit.deepSnow", Interaction.HitTest(new PointD(100, 3), none, noBalls, new[] { deep }) == HitTarget.ForPile(LedgeKind.Ground, 100));
            Check("hit.aboveSnow", Interaction.HitTest(new PointD(100, 20), none, noBalls, new[] { deep }) is null);
            Check("hit.edgeStripFree", Interaction.HitTest(new PointD(100, 0.5), none, noBalls, new[] { deep }) is null);
            var hidden = GroundPile(6, 800, new RectD(0, 0, 1512, 48));
            Check("hit.hiddenSnow", Interaction.HitTest(new PointD(800, 3), none, noBalls, new[] { hidden }) is null);
        }
        {
            var deep = GroundPile(6, 100);
            var men = new[] { (9, new RectD(80, 0, 40, 80)) };
            var balls = new[] { (4, new PointD(100, 10), 8.0) };
            Check("hit.snowmanFirst", Interaction.HitTest(new PointD(100, 3), men, balls, new[] { deep }) == HitTarget.ForSnowman(9));
            Check("hit.ballBeforePile", Interaction.HitTest(new PointD(100, 3), none, balls, new[] { deep }) == HitTarget.ForBall(4));
        }
    }
}
