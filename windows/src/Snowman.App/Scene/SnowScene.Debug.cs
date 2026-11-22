using System;
using System.Linq;
using System.Text;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>Synthetic interactions used by the debug command channel (CI smoke tests).</summary>
internal sealed partial class SnowScene
{
    public void DebugFill(double height)
    {
        foreach (var l in _ledges)
        {
            if (!Store.Piles.TryGetValue(l.Kind, out var pile)) continue;
            for (int c = 0; c < pile.ColumnCount; c++)
            {
                float need = Math.Max(0, (float)height - pile.Heights[c]);
                if (need > 0) pile.Add(pile.CenterX(c), need * (float)SnowPile.ColumnWidth);
            }
            pile.Relax(20);
            MarkDirty(l.Kind);
        }
    }

    public void DebugRoll(double x0, double x1, PointD? lift)
    {
        if (SurfaceBelow(x0, 160) is not { } start) return;
        Scoop(start.Ledge.Kind, x0 - start.Ledge.Spec.X0);
        if (_drag is not DragTarget drag || drag.Kind != DragKind.Ball) return;
        int steps = Math.Max(1, (int)(Math.Abs(x1 - x0) / 5));
        for (int i = 1; i <= steps; i++)
        {
            double x = x0 + (x1 - x0) * i / steps;
            double y = (SurfaceBelow(x, 160)?.Y ?? 0) + 8;
            DragBall(drag.Id, new PointD(x, y));
        }
        if (lift is PointD l)
        {
            DragBall(drag.Id, l);
            if (Ball(drag.Id) is Snowball b)
            {
                b.State = BallState.Falling;
                b.Velocity = VectorD.Zero;
                b.Support = null;
            }
        }
        else if (Ball(drag.Id) is Snowball b) b.State = BallState.Resting;
        _drag = null;
    }

    public void DebugThrow(double vx, double vy)
    {
        var man = _snowmen.LastOrDefault(m => m.State == FigureState.Idle);
        if (man is null) return;
        man.State = FigureState.Flying;
        man.Support = null;
        man.Velocity = new VectorD(vx, vy);
        man.Spin = -vx * 0.004;
    }

    public string DebugReport()
    {
        var sb = new StringBuilder();
        sb.AppendLine($"  size {Width:0}x{Height:0} particles {Particles.Items.Count} wantsMouse {WantsMouse}");
        foreach (var l in _ledges)
        {
            Store.Piles.TryGetValue(l.Kind, out var pile);
            int hidden = l.Vis.Hidden.Count(h => h);
            sb.AppendLine($"  ledge {l.Kind} x {l.Spec.X0:0}..{l.Spec.X1:0} y {l.Spec.Y:0} max {l.Spec.MaxHeight} area {pile?.TotalArea ?? 0:0} peak {(pile is null ? 0 : pile.Heights.Max()):0.0} hidden {hidden}/{l.Columns}");
        }
        sb.AppendLine("  balls " + string.Join(", ", _balls.Select(b => $"#{b.Id} r{b.Radius:0} {b.State} at {b.Position.X:0},{b.Position.Y:0}{(b.Hidden ? " HIDDEN" : "")}")));
        sb.AppendLine("  snowmen " + string.Join(", ", _snowmen.Select(m => $"#{m.Id} {m.Style} s{m.S:0.00} {m.State} at {m.Position.X:0},{m.Position.Y:0}")));
        sb.AppendLine($"  plow {(_plow is null ? "none" : $"at {_plow.Position.X:0} collected {_plow.Collected:0}")}");
        return sb.ToString();
    }
}
