namespace Snowman.Core;

public enum HitType { Snowman, Snowball, Pile }

/// <summary>What the mouse is over.</summary>
public readonly record struct HitTarget(HitType Type, int Id, LedgeKind Ledge, double LocalX)
{
    public static HitTarget ForSnowman(int id) => new(HitType.Snowman, id, default, 0);
    public static HitTarget ForBall(int id) => new(HitType.Snowball, id, default, 0);
    public static HitTarget ForPile(LedgeKind kind, double localX) => new(HitType.Pile, 0, kind, localX);
}

public static class Interaction
{
    /// <summary>
    /// Finds the interactive thing under point (scene coordinates). Snowmen win over snowballs,
    /// snowballs over snow; snow needs at least 3pt visible and the window's own edge stays free.
    /// </summary>
    public static HitTarget? HitTest(PointD point,
                                     IEnumerable<(int Id, RectD Frame)> snowmen,
                                     IEnumerable<(int Id, PointD Center, double Radius)> balls,
                                     IEnumerable<(LedgeSpec Spec, SnowPile Pile, Visibility Vis)> piles)
    {
        foreach (var m in snowmen)
            if (m.Frame.Contains(point)) return HitTarget.ForSnowman(m.Id);
        foreach (var b in balls)
            if (b.Center.DistanceTo(point) <= b.Radius + 2) return HitTarget.ForBall(b.Id);
        foreach (var (spec, pile, vis) in piles)
        {
            if (point.X < spec.X0 || point.X >= spec.X1) continue;
            double localX = point.X - spec.X0;
            var c = pile.Column(localX);
            if (c is null) continue;
            float visible = vis.VisibleHeight(c.Value, pile.Heights[c.Value]);
            if (visible < SnowballTuning.ScoopMinimumHeight) continue;
            if (point.Y >= spec.Y + 1.5 && point.Y <= spec.Y + visible + 3) return HitTarget.ForPile(spec.Kind, localX);
        }
        return null;
    }
}
