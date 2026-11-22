using System.Windows;
using System.Windows.Media;
using Snowman.Core;

namespace Snowman.App.Scene;

internal sealed partial class SnowScene
{
    /// <summary>Draws the whole scene. One flip makes the drawing space y-up like the simulation.</summary>
    public void Render(DrawingContext dc)
    {
        dc.PushTransform(new MatrixTransform(1, 0, 0, -1, 0, Height));
        foreach (var l in _ledges)
            if (_renderers.TryGetValue(l.Kind, out var r)) r.Draw(dc, l.Spec);
        DrawParticles(dc, true);
        foreach (var b in _balls) b.Draw(dc, SimTime);
        foreach (var m in _snowmen) m.Draw(dc, SimTime);
        _plow?.Draw(dc);
        DrawParticles(dc, false);
        Effects.Draw(dc);
        if (_showMitten && Mouse is PointD p)
            SpriteDraw.Image(dc, Sprites.Mitten, 30, 30, SpriteDraw.Local(30, 30, 0.5, 0.5, 28.0 / 30, 28.0 / 30, 0, p.X + 16, p.Y - 14));
        dc.Pop();
    }

    /// <summary>Small flakes go behind snowmen, big flakes and clumps in front.</summary>
    private void DrawParticles(DrawingContext dc, bool background)
    {
        var items = Particles.Items;
        for (int i = 0; i < items.Count; i++)
        {
            var p = items[i];
            if (p.IsClump)
            {
                if (background) continue;
                double s = p.Size * 1.3;
                dc.DrawImage(Sprites.Clump, new Rect(p.X - s / 2, p.Y - s / 2, s, s));
            }
            else
            {
                if ((p.Size < 3) != background) continue;
                double s = p.Size * 1.5;
                dc.DrawImage(Sprites.FlakeFor(p.Alpha), new Rect(p.X - s / 2, p.Y - s / 2, s, s));
            }
        }
    }
}
