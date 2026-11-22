using System;
using System.Windows.Media;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>Where a resting object sits: a ledge and a position along it.</summary>
internal readonly record struct Support(LedgeKind Kind, double LocalX);

internal enum BallState { Rolling, Carried, Falling, Resting }

/// <summary>A snowball that can be rolled, carried, thrown and stacked.</summary>
internal sealed class Snowball
{
    /// <summary>The texture is a 60pt-radius ball with a 2pt margin.</summary>
    private const double TextureRatio = 124.0 / 60.0;

    public Snowball(int id, double radius)
    {
        Id = id;
        Radius = radius;
    }

    public int Id { get; }
    public double Radius { get; set; }
    public BallState State { get; set; } = BallState.Resting;
    public VectorD Velocity { get; set; }
    public Support? Support { get; set; }
    public PointD Position { get; set; }
    public double Rotation { get; set; }
    public bool Hidden { get; set; }
    /// <summary>Scene time of a pop-in (scale) animation, or NaN.</summary>
    public double PopStart { get; set; } = double.NaN;
    /// <summary>Scene time of a fade-in, or NaN.</summary>
    public double FadeStart { get; set; } = double.NaN;

    public void Roll(double dx) => Rotation -= dx / Math.Max(Radius, 1);

    public void Draw(DrawingContext dc, double t)
    {
        if (Hidden) return;
        double scale = 1, alpha = 1;
        if (!double.IsNaN(PopStart))
        {
            double e = t - PopStart;
            scale = e < 0.18 ? 1.15 * (e / 0.18) : e < 0.28 ? 1.15 - 0.15 * ((e - 0.18) / 0.1) : 1;
            if (e >= 0.28) PopStart = double.NaN;
        }
        if (!double.IsNaN(FadeStart))
        {
            double e = t - FadeStart;
            alpha = Math.Min(1, e / 0.15);
            if (e >= 0.15) FadeStart = double.NaN;
        }
        double d = Radius * TextureRatio * Math.Max(0.001, scale);
        var m = SpriteDraw.Local(124, 124, 0.5, 0.5, d / 124, d / 124, Rotation, Position.X, Position.Y);
        SpriteDraw.Image(dc, Sprites.Snowball, 124, 124, m, alpha);
    }
}
