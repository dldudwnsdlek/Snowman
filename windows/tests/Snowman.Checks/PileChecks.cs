using Snowman.Core;
using static Snowman.Checks.Harness;

namespace Snowman.Checks;

internal static class PileChecks
{
    private static SnowPile FilledFlat(double width, float maxHeight, float areaPerStep)
    {
        var p = new SnowPile(width, maxHeight);
        for (double x = 1; x < width; x += SnowPile.ColumnWidth) p.Add(x, areaPerStep);
        return p;
    }

    public static void Run()
    {
        {
            var p = new SnowPile(100, 14);
            float over = p.Add(50, 10);
            Close("addIncreasesArea.area", p.TotalArea, 10, 0.01);
            Close("addIncreasesArea.overflow", over, 0, 0.0001);
        }
        {
            var p = new SnowPile(100, 14);
            Check("capacityTapersAtEnds.end", p.Capacity(0) < 0.5f * 14, $"cap0 {p.Capacity(0)}");
            Check("capacityTapersAtEnds.middle", p.Capacity(p.ColumnCount / 2) == 14);
        }
        {
            var p = new SnowPile(100, 14);
            float over = p.Add(50, 10_000);
            Check("overflowReturnedWhenFull.overflow", over > 0);
            bool capped = Enumerable.Range(0, p.ColumnCount).All(c => p.Heights[c] <= p.Capacity(c) + 0.0001f);
            Check("overflowReturnedWhenFull.capped", capped);
        }
        {
            var p = new SnowPile(100, 14);
            for (int i = 0; i < 20; i++) p.Add(50, 6);
            p.Relax(50);
            float maxStep = 0;
            for (int i = 0; i < p.ColumnCount - 1; i++) maxStep = Math.Max(maxStep, Math.Abs(p.Heights[i] - p.Heights[i + 1]));
            Check("relaxLimitsSlope", maxStep <= 1.2f + 0.01f, $"maxStep {maxStep}");
        }
        {
            var p = new SnowPile(100, 14);
            p.Add(1, 8);
            var spill = p.Relax(50);
            Check("relaxSpillsAtEnds", spill.Left > 0, $"left {spill.Left}");
        }
        {
            var p = FilledFlat(100, 14, 12);
            float before = p.TotalArea;
            float got = p.Take(10, 30, 20);
            Close("takeRemovesUpToMax.returned", got, 20, 0.01);
            Close("takeRemovesUpToMax.areaDrop", before - p.TotalArea, 20, 0.01);
        }
        {
            var p = FilledFlat(100, 14, 12);
            double before = p.TotalArea;
            p.Resample(160);
            Check("resamplePreservesVolume.width", p.Width == 160);
            Close("resamplePreservesVolume.area", p.TotalArea, before, before * 0.05);
        }
    }
}
