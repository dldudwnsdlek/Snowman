using System;
using System.Collections.Generic;
using System.Windows.Media;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>The orange snowplow: body, two spinning wheels, a blinking beacon and the snow mound it pushes.</summary>
internal sealed class Snowplow
{
    private double _wheelRotation;
    private double _glow;

    public Snowplow(LedgeKind ledge, double scale)
    {
        Ledge = ledge;
        S = scale;
    }

    public LedgeKind Ledge { get; }
    public double S { get; }
    public double DriveSpeed { get; } = 230;
    public float Collected { get; set; }
    public bool Finished { get; set; }
    public bool Falling { get; set; }
    public double FallVelocity { get; set; }
    public HashSet<int> Hopped { get; } = new();
    public PointD Position { get; set; }
    public double FadeStart { get; set; } = double.NaN;
    public double Alpha { get; private set; } = 1;

    public double BladeX => Position.X + SpriteArt.PlowBladeFront * S;
    public double Width => SpriteArt.PlowWidth * S;
    public double MoundRadius => Math.Min(34, 3 + Math.Sqrt(Collected) * 0.55);

    public void Animate(double t, double distance)
    {
        _wheelRotation -= distance / (11 * S);
        _glow = 0.35 + 0.65 * Math.Max(0, Math.Sin(t * 9));
        if (!double.IsNaN(FadeStart)) Alpha = Math.Clamp(1 - (t - FadeStart) / 0.5, 0, 1);
    }

    public void Draw(DrawingContext dc)
    {
        if (Alpha <= 0.01) return;
        var world = SpriteDraw.Node(S, S, 0, Position.X, Position.Y);
        dc.PushOpacity(Alpha);
        SpriteDraw.Image(dc, Sprites.Plow, SpriteArt.PlowWidth, SpriteArt.PlowHeight,
                         Matrix.Multiply(SpriteDraw.Local(SpriteArt.PlowWidth, SpriteArt.PlowHeight, 0, 0, 1, 1, 0, 0, 0), world));
        foreach (var (wx, wy) in SpriteArt.PlowWheelCenters)
            SpriteDraw.Image(dc, Sprites.PlowWheel, 24, 24, Matrix.Multiply(SpriteDraw.Local(24, 24, 0.5, 0.5, 1, 1, _wheelRotation, wx, wy), world));
        var (bx, by) = SpriteArt.PlowBeaconPosition;
        SpriteDraw.Image(dc, Sprites.PlowBeacon, 12, 10, Matrix.Multiply(SpriteDraw.Local(12, 10, 0.5, 0, 1, 1, 0, bx, by), world));
        SpriteDraw.Image(dc, Sprites.BeaconGlow, 32, 32, Matrix.Multiply(SpriteDraw.Local(32, 32, 0.5, 0.5, 34.0 / 32, 34.0 / 32, 0, bx, by + 5), world), _glow);
        if (Collected >= 4)
        {
            double r = MoundRadius;
            double w = r * 2.1 / S, h = r * 1.25 / S;
            SpriteDraw.Image(dc, Sprites.Snowball, 124, 124,
                             Matrix.Multiply(SpriteDraw.Local(124, 124, 0, 0.08, w / 124, h / 124, 0, SpriteArt.PlowBladeFront - 6, 0), world));
        }
        dc.Pop();
    }
}
