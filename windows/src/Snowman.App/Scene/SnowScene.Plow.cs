using System;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>제설차 부르기: drives along the taskbar (or the ground when it is hidden) and pushes the snow off.</summary>
internal sealed partial class SnowScene
{
    private Snowplow? _plow;

    public bool PlowActive => _plow is not null;

    public void CallPlow()
    {
        if (_plow is not null) return;
        Store.ClearStash(LedgeKind.Taskbar);
        if ((Ledge(LedgeKind.Taskbar) ?? Ledge(LedgeKind.Ground)) is not FrameLedge l) return;
        bool onBar = l.Kind == LedgeKind.Taskbar;
        var plow = new Snowplow(l.Kind, onBar ? 0.72 : 0.8);
        if (onBar)
        {
            plow.Position = new PointD(Math.Max(l.Spec.X0, 0) + 6 - SpriteArt.PlowWidth * plow.S * 0.15, l.Spec.Y + 70);
            plow.Falling = true;
        }
        else plow.Position = new PointD(-plow.Width - 10, l.Spec.Y);
        _plow = plow;
        Sound.Play(SoundEffect.Horn, 0.3);
    }

    private void UpdatePlow(double dt)
    {
        if (_plow is not Snowplow plow) return;
        if (Ledge(plow.Ledge) is not FrameLedge l)
        {
            SpillMound(plow, plow.BladeX, plow.Position.Y);
            if (!plow.Finished)
            {
                plow.Finished = true;
                plow.FadeStart = SimTime;
            }
        }
        if (plow.Finished)
        {
            plow.Position = new PointD(plow.Position.X + plow.DriveSpeed * dt, plow.Position.Y);
            plow.FallVelocity += ThrowTuning.Gravity * 0.5 * dt;
            plow.Position = new PointD(plow.Position.X, plow.Position.Y + plow.FallVelocity * dt);
            plow.Animate(SimTime, plow.DriveSpeed * dt);
            if (plow.Alpha <= 0.01 || plow.Position.X > Width + 20) _plow = null;
            return;
        }
        if (Ledge(plow.Ledge) is not FrameLedge ledge) return;
        if (plow.Falling)
        {
            plow.FallVelocity += ThrowTuning.Gravity * dt;
            plow.Position = new PointD(plow.Position.X, plow.Position.Y + plow.FallVelocity * dt);
            if (plow.Position.Y <= ledge.Spec.Y)
            {
                plow.Position = new PointD(plow.Position.X, ledge.Spec.Y);
                plow.Falling = false;
                plow.FallVelocity = 0;
                Effects.Puff(plow.Position.X + plow.Width / 2, ledge.Spec.Y, 40);
            }
            plow.Animate(SimTime, 0);
            return;
        }
        double oldBlade = plow.BladeX;
        double step = plow.DriveSpeed * dt;
        plow.Position = new PointD(plow.Position.X + step, ledge.Spec.Y);
        double newBlade = plow.BladeX;
        if (Store.Piles.TryGetValue(ledge.Kind, out var pile))
        {
            double lo = Math.Max(0, oldBlade - 1 - ledge.Spec.X0);
            double hi = Math.Min(ledge.Spec.Width, newBlade - ledge.Spec.X0);
            if (hi > lo)
            {
                float got = pile.TakeAll(lo, hi);
                if (got > 0) { plow.Collected += got; MarkDirty(ledge.Kind); }
            }
            double behind = Math.Max(0, plow.Position.X - ledge.Spec.X0);
            if (behind > 0)
            {
                float left = pile.TakeAll(0, Math.Min(ledge.Spec.Width, behind));
                if (left > 0) { plow.Collected += left; MarkDirty(ledge.Kind); }
            }
        }
        if (plow.Collected > 60 && (int)(SimTime * 20) % 3 == 0)
            Particles.SpawnClump(newBlade + 4, ledge.Spec.Y + Math.Min(20, Math.Sqrt(plow.Collected) * 0.6),
                                 20 + Random.Shared.NextDouble() * 60, 30 + Random.Shared.NextDouble() * 60, 0.5f);
        PushObjects(plow, ledge);
        plow.Animate(SimTime, step);
        if (newBlade >= ledge.Spec.X1)
        {
            SpillMound(plow, ledge.Spec.X1, ledge.Spec.Y);
            plow.Finished = true;
            plow.FallVelocity = ledge.Kind == LedgeKind.Taskbar ? 60 : 0;
            plow.FadeStart = SimTime + 0.25;
            Sound.Play(SoundEffect.Horn, 0.25);
        }
    }

    private void PushObjects(Snowplow plow, FrameLedge l)
    {
        double blade = plow.BladeX;
        double moundWidth = plow.MoundRadius * 2;
        foreach (var b in _balls)
        {
            if (b.State != BallState.Resting || b.Support?.Kind != l.Kind) continue;
            double x = b.Position.X;
            if (x - b.Radius < blade + moundWidth * 0.6 && x > plow.Position.X)
            {
                double newX = blade + moundWidth * 0.6 + b.Radius;
                if (newX >= l.Spec.X1)
                {
                    b.State = BallState.Falling;
                    b.Support = null;
                    b.Velocity = new VectorD(plow.DriveSpeed, 60);
                }
                else
                {
                    b.Support = new Support(l.Kind, newX - l.Spec.X0);
                    b.Roll(newX - x);
                }
            }
        }
        foreach (var man in _snowmen)
        {
            if (man.State != FigureState.Idle || man.Support?.Kind != l.Kind || plow.Hopped.Contains(man.Id)) continue;
            if (man.Position.X - man.HalfWidth < blade + 40 && man.Position.X > plow.Position.X)
            {
                plow.Hopped.Add(man.Id);
                man.State = FigureState.Flying;
                man.Support = null;
                man.Velocity = new VectorD(-plow.DriveSpeed * 0.9, 760);
                man.Spin = 0;
                man.DanceAfterLanding = true;
            }
        }
    }

    private void SpillMound(Snowplow plow, double x, double y)
    {
        if (plow.Collected <= 1) return;
        int count = Math.Clamp((int)(plow.Collected / 5), 8, 220);
        float each = plow.Collected / count;
        for (int i = 0; i < count; i++)
        {
            double h = (i % 12) * 1.6;
            Particles.SpawnClump(x - 6 + Random.Shared.NextDouble() * 10, y + 2 + h, 40 + Random.Shared.NextDouble() * 130,
                                 -10 + Random.Shared.NextDouble() * 130, each);
        }
        plow.Collected = 0;
        Sound.Play(SoundEffect.Whoosh, 0.35);
    }
}
