using System;
using System.Collections.Generic;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>A falling snowflake or clump of snow.</summary>
internal struct Particle
{
    public double X, Y, PrevY, Vx, Vy, Size, SwayAmp, SwayFreq, Phase, Alpha, Spin, Rotation, Age;
    public float Area;
    public bool IsClump;
}

internal delegate bool LandDelegate(ref Particle p);

internal sealed class ParticleSystem
{
    /// <summary>Snow area each landed flake adds, relative to its disc area.</summary>
    public const float Accumulation = 0.65f;

    public List<Particle> Items { get; } = new(2048);

    public void SpawnFlake(double x, double y, SnowAmount amount)
    {
        var (lo, hi) = amount.SizeRange();
        double size = lo + (hi - lo) * Random.Shared.NextDouble();
        double t = (size - lo) / Math.Max(0.01, hi - lo);
        Items.Add(new Particle
        {
            X = x, Y = y, PrevY = y,
            Vy = -(26 + size * 8.5 + Random.Shared.NextDouble() * 14),
            Size = size,
            SwayAmp = 4 + Random.Shared.NextDouble() * 12,
            SwayFreq = 0.5 + Random.Shared.NextDouble(),
            Phase = Random.Shared.NextDouble() * 2 * Math.PI,
            Alpha = 0.55 + 0.45 * t,
            Area = (float)(Math.PI * (size / 2) * (size / 2)) * Accumulation,
        });
    }

    public void SpawnClump(double x, double y, double vx, double vy, float area)
    {
        double size = Math.Min(9, Math.Max(2.6, Math.Sqrt(area) * 1.1));
        Items.Add(new Particle
        {
            X = x, Y = y, PrevY = y, Vx = vx, Vy = vy, Size = size, Area = area, IsClump = true, Alpha = 1,
            Spin = Random.Shared.NextDouble() * 12 - 6,
        });
    }

    /// <summary>Moves everything one step; land returns true when the particle settled (it is removed).</summary>
    public void Update(double dt, double wind, double width, LandDelegate land)
    {
        for (int i = Items.Count - 1; i >= 0; i--)
        {
            var p = Items[i];
            p.PrevY = p.Y;
            p.Age += dt;
            if (p.IsClump)
            {
                p.Vy = Math.Max(p.Vy - 900 * dt, -560);
                p.Vx -= p.Vx * Math.Min(1, 0.9 * dt);
                p.X += p.Vx * dt;
                p.Y += p.Vy * dt;
                p.Rotation += p.Spin * dt;
            }
            else
            {
                double sway = p.SwayAmp * p.SwayFreq * Math.Cos(p.SwayFreq * p.Age + p.Phase);
                p.X += (wind * (0.5 + p.Size / 8) + sway) * dt;
                p.Y += p.Vy * dt;
            }
            if (land(ref p) || p.Y < -30 || p.X < -120 || p.X > width + 120)
            {
                int last = Items.Count - 1;
                Items[i] = Items[last];
                Items.RemoveAt(last);
            }
            else
            {
                Items[i] = p;
            }
        }
    }
}
