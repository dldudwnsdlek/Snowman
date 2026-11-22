using System;
using System.Collections.Generic;
using System.Linq;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App.Scene;

internal enum DragKind { Ball, Snowman }

internal readonly record struct DragTarget(DragKind Kind, int Id, VectorD Offset);

/// <summary>Snowballs, snowmen and mouse interaction.</summary>
internal sealed partial class SnowScene
{
    public const int MaxSnowmen = 12;

    private readonly List<Snowball> _balls = new();
    private readonly List<SnowmanFigure> _snowmen = new();
    private readonly StyleBag _styleBag = new();
    private readonly Dictionary<int, SnowmanStyle> _pendingStyles = new();
    private readonly List<(double T, PointD P)> _samples = new();
    private int _nextId = 1;
    private DragTarget? _drag;
    private (PointD P, double T)? _press;
    private bool _showMitten;

    public IReadOnlyList<Snowball> Balls => _balls;
    public IReadOnlyList<SnowmanFigure> Snowmen => _snowmen;

    private int MakeId() => _nextId++;
    private Snowball? Ball(int id) => _balls.FirstOrDefault(b => b.Id == id);
    private SnowmanFigure? Figure(int id) => _snowmen.FirstOrDefault(m => m.Id == id);
    private RectD Bounds => new(0, 0, Width, Height);

    // ---- Hover ----

    public HitTarget? HoverTarget(PointD p)
    {
        var men = _snowmen.Where(m => m.State != FigureState.Building && !m.Hidden).Select(m => (m.Id, m.HitFrame));
        var balls = _balls.Where(b => !b.Hidden).Select(b => (b.Id, b.Position, b.Radius));
        var piles = _ledges.Where(l => Store.Piles.ContainsKey(l.Kind)).Select(l => (l.Spec, Store.Piles[l.Kind], l.Vis));
        return Interaction.HitTest(p, men, balls, piles);
    }

    private void UpdateObjects(double dt)
    {
        HitTarget? hover = null;
        if (_drag is null && Mouse is PointD m) hover = HoverTarget(m);
        WantsMouse = _drag is not null || hover is not null;
        _showMitten = Mouse is not null && (hover is not null || _drag?.Kind == DragKind.Ball);
        UpdateBalls(dt);
        UpdateSnowmen(dt);
        UpdatePlow(dt);
    }

    // ---- Mouse ----

    private PointD Clamp(PointD p) => new(Math.Clamp(p.X, 2, Width - 2), Math.Clamp(p.Y, 2, Height - 2));

    private void Record(double t, PointD p)
    {
        _samples.Add((t, p));
        _samples.RemoveAll(s => t - s.T > 0.12);
    }

    private VectorD ReleaseVelocity()
    {
        if (_samples.Count < 2) return VectorD.Zero;
        var first = _samples[0];
        var last = _samples[^1];
        double dt = last.T - first.T;
        if (dt <= 0.008) return VectorD.Zero;
        return new VectorD((last.P.X - first.P.X) / dt, (last.P.Y - first.P.Y) / dt);
    }

    private static VectorD Limit(VectorD v, double max)
    {
        double s = v.Length;
        return s <= max ? v : new VectorD(v.Dx / s * max, v.Dy / s * max);
    }

    public void MouseDown(PointD p, double t)
    {
        _samples.Clear();
        _samples.Add((t, p));
        _press = (p, t);
        if (HoverTarget(p) is not HitTarget target) return;
        switch (target.Type)
        {
            case HitType.Snowman when Figure(target.Id) is SnowmanFigure man:
                man.State = FigureState.Dragged;
                man.Support = null;
                man.DragTarget = man.Position;
                _drag = new DragTarget(DragKind.Snowman, man.Id, new VectorD(man.Position.X - p.X, man.Position.Y - p.Y));
                Sound.Play(SoundEffect.Pop, 0.2);
                break;
            case HitType.Snowball when Ball(target.Id) is Snowball ball:
                ball.State = BallState.Rolling;
                _drag = new DragTarget(DragKind.Ball, ball.Id, VectorD.Zero);
                break;
            case HitType.Pile:
                Scoop(target.Ledge, target.LocalX);
                break;
        }
    }

    public void MouseDragged(PointD p, double t)
    {
        p = Clamp(p);
        Record(t, p);
        if (_drag is not DragTarget drag) return;
        if (drag.Kind == DragKind.Ball) DragBall(drag.Id, p);
        else if (Figure(drag.Id) is SnowmanFigure man) man.DragTarget = new PointD(p.X + drag.Offset.Dx, p.Y + drag.Offset.Dy);
    }

    public void MouseUp(PointD p, double t)
    {
        Record(t, p);
        if (_drag is not DragTarget drag) return;
        _drag = null;
        var v = ReleaseVelocity();
        if (drag.Kind == DragKind.Ball)
        {
            if (Ball(drag.Id) is not Snowball b) return;
            if (b.State == BallState.Carried)
            {
                b.State = BallState.Falling;
                b.Support = null;
                b.Velocity = Limit(v, 1800);
            }
            else b.State = BallState.Resting;
        }
        else if (Figure(drag.Id) is SnowmanFigure man)
        {
            bool isClick = _press is { } press && press.P.DistanceTo(p) < 4 && t - press.T < 0.35;
            man.State = FigureState.Flying;
            man.Velocity = isClick ? VectorD.Zero : Limit(v, 3200);
            man.Spin = isClick ? 0 : -man.Velocity.Dx * 0.004;
            man.DanceAfterLanding = isClick;
        }
    }

    /// <summary>Mouse capture lost mid-drag (e.g. another window took it): drop whatever was held.</summary>
    public void CancelDrag()
    {
        if (_drag is not DragTarget drag) return;
        _drag = null;
        if (drag.Kind == DragKind.Ball && Ball(drag.Id) is Snowball b && b.State == BallState.Carried)
        {
            b.State = BallState.Falling;
            b.Velocity = VectorD.Zero;
        }
        else if (drag.Kind == DragKind.Ball && Ball(drag.Id) is Snowball rolling) rolling.State = BallState.Resting;
        else if (Figure(drag.Id) is SnowmanFigure man)
        {
            man.State = FigureState.Flying;
            man.Velocity = VectorD.Zero;
        }
    }

    // ---- Snowballs ----

    /// <summary>Presses into the snow and lifts a handful as a small snowball.</summary>
    public void Scoop(LedgeKind kind, double localX)
    {
        if (Ledge(kind) is not FrameLedge l || !Store.Piles.TryGetValue(kind, out var pile)) return;
        float taken = pile.Take(localX - 7, localX + 7, 60);
        MarkDirty(kind);
        double r = Physics.GrownRadius(SnowballTuning.StartRadius, taken * 0.4);
        var b = new Snowball(MakeId(), r);
        double x = l.Spec.X0 + localX;
        double surface = SurfaceY(l, x) ?? l.Spec.Y;
        b.Position = new PointD(x, surface + r * 0.9);
        b.State = BallState.Rolling;
        b.Support = new Support(kind, localX);
        _balls.Add(b);
        _drag = new DragTarget(DragKind.Ball, b.Id, VectorD.Zero);
        Effects.Puff(x, surface, 18);
        Sound.Play(SoundEffect.Pop, 0.2);
    }

    /// <summary>Rolls the ball along the snow under the cursor (growing it), or carries it when lifted.</summary>
    public void DragBall(int id, PointD p)
    {
        if (Ball(id) is not Snowball b) return;
        double r = b.Radius;
        var below = SurfaceBelow(p.X, p.Y + r * 0.5);
        if (below is null || p.Y - (below.Value.Y + r) >= r + 16)
        {
            b.State = BallState.Carried;
            b.Support = null;
            b.Position = p;
            return;
        }
        var (ledge, sy) = below.Value;
        double oldX = b.Position.X, newX = p.X, dx = newX - oldX;
        if (Math.Abs(dx) > 0.01 && Store.Piles.TryGetValue(ledge.Kind, out var pile))
        {
            double newLocal = newX - ledge.Spec.X0;
            double oldLocal = b.Support?.Kind == ledge.Kind ? oldX - ledge.Spec.X0 : newLocal;
            double reach = Math.Min(r * 0.8, 10);
            double under = pile.HeightAt(newLocal);
            if (under > 0.3)
            {
                float wanted = (float)(Math.Abs(dx) * Math.Min(under, 9) * 0.9);
                float got = pile.Take(Math.Min(oldLocal, newLocal) - reach, Math.Max(oldLocal, newLocal) + reach, wanted);
                if (got > 0)
                {
                    b.Radius = Physics.GrownRadius(b.Radius, got);
                    MarkDirty(ledge.Kind);
                }
            }
        }
        double surfaceNow = SurfaceY(ledge, newX) ?? sy;
        b.Position = new PointD(newX, surfaceNow + b.Radius * 0.9);
        b.Roll(dx);
        b.State = BallState.Rolling;
        b.Support = new Support(ledge.Kind, newX - ledge.Spec.X0);
    }

    private enum SupportState { Visible, Hidden, Gone }

    /// <summary>Visible: stand there. Hidden: behind a front window or away for a moment. Gone: the window closed.</summary>
    private (SupportState State, double X, double Surface) SupportOf(Support? support)
    {
        if (support is not Support sup) return (SupportState.Gone, 0, 0);
        if (Ledge(sup.Kind) is FrameLedge l)
        {
            double x = l.Spec.X0 + sup.LocalX;
            if (x < l.Spec.X0 || x >= l.Spec.X1) return (SupportState.Gone, 0, 0);
            return SurfaceY(l, x) is double s ? (SupportState.Visible, x, s) : (SupportState.Hidden, 0, 0);
        }
        return Store.Stash.ContainsKey(sup.Kind) ? (SupportState.Hidden, 0, 0) : (SupportState.Gone, 0, 0);
    }

    private IEnumerable<(int Id, PointD Center, double Radius)> RestingBalls(int except) =>
        _balls.Where(b => b.Id != except && b.State == BallState.Resting && !b.Hidden).Select(b => (b.Id, b.Position, b.Radius));

    private void UpdateBalls(double dt)
    {
        foreach (var b in _balls.ToList())
        {
            switch (b.State)
            {
                case BallState.Rolling:
                case BallState.Carried:
                    continue;
                case BallState.Resting:
                {
                    var (state, x, s) = SupportOf(b.Support);
                    if (state == SupportState.Visible)
                    {
                        b.Hidden = false;
                        b.Position = new PointD(x, s + b.Radius * 0.9);
                    }
                    else if (state == SupportState.Hidden) b.Hidden = true;
                    else
                    {
                        b.Hidden = false;
                        b.State = BallState.Falling;
                        b.Support = null;
                        b.Velocity = VectorD.Zero;
                    }
                    break;
                }
                case BallState.Falling:
                {
                    double r = b.Radius;
                    double prevBottom = b.Position.Y - r * 0.9;
                    var v = new VectorD(b.Velocity.Dx, b.Velocity.Dy + ThrowTuning.Gravity * dt);
                    var pos = new PointD(b.Position.X + v.Dx * dt, b.Position.Y + v.Dy * dt);
                    var hit = Physics.BounceOffWalls(ref pos, ref v, r, r, Bounds, ThrowTuning.WallRestitution);
                    if (hit is { } h && h.Speed > 200) Effects.Puff(pos.X, pos.Y, r * 2);
                    b.Position = pos;
                    b.Velocity = v;
                    b.Roll(v.Dx * dt);
                    double bottom = pos.Y - r * 0.9;
                    if (v.Dy < 0)
                    {
                        foreach (var other in RestingBalls(b.Id).ToList())
                        {
                            double top = other.Center.Y + other.Radius;
                            if (prevBottom < top - 2 || bottom > top + 12) continue;
                            if (Physics.StackCandidate(new PointD(pos.X, top + r), r, new[] { other }) is not null && Ball(other.Id) is Snowball target)
                            {
                                FormSnowman(b, target);
                                return;
                            }
                        }
                    }
                    var landing = v.Dy <= 0 ? SurfaceBelow(pos.X, prevBottom + 1) : null;
                    if (landing is not null && bottom <= landing.Value.Y)
                    {
                        var (ledge, sy) = landing.Value;
                        b.Position = new PointD(pos.X, sy + r * 0.9);
                        if (v.Dy < -520) b.Velocity = new VectorD(v.Dx * 0.7, -v.Dy * 0.25);
                        else
                        {
                            b.State = BallState.Resting;
                            b.Velocity = VectorD.Zero;
                            b.Support = new Support(ledge.Kind, pos.X - ledge.Spec.X0);
                        }
                        if (v.Dy < -300)
                        {
                            Effects.Puff(pos.X, sy, r * 1.6);
                            Sound.Play(SoundEffect.Thud, 0.2);
                        }
                    }
                    if (pos.Y < -200) _balls.Remove(b);
                    break;
                }
            }
        }
    }

    // ---- Snowmen ----

    private void FormSnowman(Snowball dropped, Snowball bottom)
    {
        double big = Math.Max(dropped.Radius, bottom.Radius);
        var basePoint = new PointD(bottom.Position.X, bottom.Position.Y - bottom.Radius * 0.9);
        var support = bottom.Support;
        _balls.Remove(dropped);
        _balls.Remove(bottom);
        var style = _pendingStyles.Remove(dropped.Id, out var pending) ? pending : _styleBag.Next();
        var man = AddSnowman(style, big, basePoint, support);
        man.PlayBuildSequence(SimTime, Effects);
    }

    private SnowmanFigure AddSnowman(SnowmanStyle style, double bodyRadius, PointD basePoint, Support? support)
    {
        var man = new SnowmanFigure(MakeId(), style, bodyRadius) { Position = basePoint, Support = support };
        _snowmen.Add(man);
        while (_snowmen.Count > MaxSnowmen)
        {
            var old = _snowmen[0];
            _snowmen.RemoveAt(0);
            Effects.Puff(old.Center.X, old.Center.Y, 60 * old.S);
        }
        return man;
    }

    /// <summary>Menu: two balls appear on the taskbar (or the ground) and stack themselves into a snowman.</summary>
    public void SpawnSnowman(SnowmanStyle? style)
    {
        if ((Ledge(LedgeKind.Taskbar) ?? Ledge(LedgeKind.Ground)) is not FrameLedge target) return;
        const double r = 30;
        double lo = target.Spec.X0 + 50, hi = Math.Max(lo + 1, target.Spec.X1 - 50);
        double x = lo + Random.Shared.NextDouble() * (hi - lo);
        for (int i = 0; i < 12; i++)
        {
            double candidate = lo + Random.Shared.NextDouble() * (hi - lo);
            bool crowded = _snowmen.Any(m => Math.Abs(m.Position.X - candidate) < 80) || _balls.Any(b => Math.Abs(b.Position.X - candidate) < 70);
            x = candidate;
            if (!crowded) break;
        }
        double s = SurfaceY(target, x) ?? target.Spec.Y;
        var body = new Snowball(MakeId(), r)
        {
            Position = new PointD(x, s + r * 0.9), State = BallState.Resting, Support = new Support(target.Kind, x - target.Spec.X0), PopStart = SimTime,
        };
        _balls.Add(body);
        Effects.Puff(x, s, 50);
        var head = new Snowball(MakeId(), 21)
        {
            Position = new PointD(x, Math.Min(Height - 30, s + 2 * r + 160)), State = BallState.Falling, FadeStart = SimTime,
        };
        if (style is SnowmanStyle st) _pendingStyles[head.Id] = st;
        _balls.Add(head);
    }

    private void UpdateSnowmen(double dt)
    {
        foreach (var man in _snowmen.ToList())
        {
            switch (man.State)
            {
                case FigureState.Building:
                case FigureState.Idle:
                {
                    var (state, x, s) = SupportOf(man.Support);
                    if (state == SupportState.Visible)
                    {
                        man.Hidden = false;
                        man.Position = new PointD(x, s - 1);
                    }
                    else if (state == SupportState.Hidden) man.Hidden = true;
                    else
                    {
                        man.Hidden = false;
                        if (man.State == FigureState.Building) man.FinishInstantly();
                        man.State = FigureState.Flying;
                        man.Support = null;
                        man.Velocity = VectorD.Zero;
                    }
                    break;
                }
                case FigureState.Dragged:
                {
                    double k = 1 - Math.Exp(-dt * 22);
                    var target = man.DragTarget;
                    var newPos = new PointD(man.Position.X + (target.X - man.Position.X) * k, man.Position.Y + (target.Y - man.Position.Y) * k);
                    double vx = (newPos.X - man.Position.X) / Math.Max(dt, 0.001);
                    man.Position = newPos;
                    double wanted = Math.Clamp(-vx * 0.0007, -0.7, 0.7);
                    man.Angle += (wanted - man.Angle) * Math.Min(1, dt * 10);
                    break;
                }
                case FigureState.Flying:
                    if (FlyStep(man, dt)) return;
                    break;
            }
            man.Animate(SimTime, dt, Mouse);
        }
    }

    /// <summary>Moves a thrown snowman. Returns true when the list changed (shattered or lost).</summary>
    private bool FlyStep(SnowmanFigure man, double dt)
    {
        double prevY = man.Position.Y;
        var v = new VectorD(man.Velocity.Dx, man.Velocity.Dy + ThrowTuning.Gravity * dt);
        var center = new PointD(man.Center.X + v.Dx * dt, man.Center.Y + v.Dy * dt);
        if (Physics.BounceOffWalls(ref center, ref v, man.HalfWidth, man.HalfHeight, Bounds, ThrowTuning.WallRestitution) is { } hit)
        {
            var contact = new PointD(hit.Side == WallSide.Left ? 4 : hit.Side == WallSide.Right ? Width - 4 : center.X,
                                     hit.Side == WallSide.Top ? Height - 4 : center.Y);
            Effects.Puff(contact.X, contact.Y, 46 * man.S);
            switch (Physics.Impact(hit.Speed))
            {
                case ImpactLevel.Soft:
                    Sound.Play(SoundEffect.Thud, 0.2);
                    break;
                case ImpactLevel.Crash:
                    double inX = contact.X + (hit.Side == WallSide.Left ? 60 : hit.Side == WallSide.Right ? -60 : 0);
                    double inY = contact.Y + (hit.Side == WallSide.Top ? -50 : 70 * man.S);
                    Effects.CrashText(inX, inY, Width, Height);
                    Sound.Play(SoundEffect.Crash, 0.45);
                    Burst(contact, 10, 2);
                    break;
                case ImpactLevel.Shatter:
                    man.Velocity = v;
                    man.Position = new PointD(center.X, center.Y - 50 * man.S);
                    Shatter(man);
                    return true;
            }
            man.Spin = -man.Spin * 0.5 + (hit.Side == WallSide.Right ? 3 : hit.Side == WallSide.Left ? -3 : 0);
        }
        man.Velocity = v;
        man.Position = new PointD(center.X, center.Y - 50 * man.S);
        man.Angle += man.Spin * dt;
        var landing = v.Dy <= 0 ? SurfaceBelow(man.Position.X, prevY + 1) : null;
        if (landing is not null && man.Position.Y <= landing.Value.Y)
        {
            var (ledge, sy) = landing.Value;
            double impact = -v.Dy;
            man.Position = new PointD(man.Position.X, sy);
            if (Physics.Impact(impact) == ImpactLevel.Shatter)
            {
                Shatter(man);
                return true;
            }
            if (impact > 520)
            {
                man.Velocity = new VectorD(v.Dx * 0.6, impact * 0.32);
                man.Spin *= 0.5;
                Effects.Puff(man.Position.X, sy, 50 * man.S);
                Sound.Play(SoundEffect.Thud, 0.3);
                if (Physics.Impact(impact) == ImpactLevel.Crash)
                {
                    Effects.CrashText(man.Position.X, sy + 130 * man.S, Width, Height);
                    Sound.Play(SoundEffect.Crash, 0.4);
                }
            }
            else
            {
                man.State = FigureState.Idle;
                man.Velocity = VectorD.Zero;
                man.Support = new Support(ledge.Kind, man.Position.X - ledge.Spec.X0);
                man.SettleUpright();
                man.AngleVelocity = -v.Dx * 0.002;
                if (impact > 150) Effects.Puff(man.Position.X, sy, 34 * man.S);
                if (man.DanceAfterLanding)
                {
                    man.DanceAfterLanding = false;
                    man.Dance(SimTime);
                }
            }
        }
        if (man.Position.Y < -400)
        {
            _snowmen.Remove(man);
            return true;
        }
        return false;
    }

    private void Burst(PointD p, int count, float area)
    {
        for (int i = 0; i < count; i++)
            Particles.SpawnClump(p.X + Random.Shared.NextDouble() * 16 - 8, p.Y + Random.Shared.NextDouble() * 16 - 8,
                                 Random.Shared.NextDouble() * 440 - 220, Random.Shared.NextDouble() * 340 - 40, area);
    }

    /// <summary>와장창: the snowman breaks; its two balls survive and can be stacked again.</summary>
    private void Shatter(SnowmanFigure man)
    {
        double s = man.S;
        foreach (var part in new[] { SnowmanPart.Hat, SnowmanPart.Nose, SnowmanPart.LeftArm, SnowmanPart.RightArm, SnowmanPart.Scarf, SnowmanPart.ScarfTail, SnowmanPart.Buttons })
        {
            if (!man.IsPartVisible(part)) continue;
            var (bmp, info) = man.Parts[part];
            var p = man.PartPosition(part);
            Effects.Debris(bmp, info.Width, info.Height, p.X, p.Y,
                           Random.Shared.NextDouble() * 760 - 380 + man.Velocity.Dx * 0.2, 120 + Random.Shared.NextDouble() * 400,
                           Random.Shared.NextDouble() * 28 - 14, s, man.Angle);
        }
        var body = new Snowball(MakeId(), 30 * s * 0.9)
        {
            Position = Clamp(new PointD(man.Position.X, man.Position.Y + 30 * s)), State = BallState.Falling,
            Velocity = new VectorD(-man.Velocity.Dx * 0.15 + Random.Shared.NextDouble() * 300 - 150, 150 + Random.Shared.NextDouble() * 200),
        };
        var head = new Snowball(MakeId(), 21 * s * 0.9)
        {
            Position = Clamp(new PointD(man.Position.X, man.Position.Y + 71 * s)), State = BallState.Falling,
            Velocity = new VectorD(Random.Shared.NextDouble() * 520 - 260, 250 + Random.Shared.NextDouble() * 230),
        };
        _balls.Add(body);
        _balls.Add(head);
        Burst(man.Center, 26, (float)(3 * s));
        Effects.Puff(man.Center.X, man.Center.Y, 90 * s);
        Effects.CrashText(man.Center.X, man.Center.Y + 40 * s, Width, Height, size: 34);
        Sound.Play(SoundEffect.Crash, 0.6);
        _snowmen.Remove(man);
    }

    public void ClearSnowmen()
    {
        foreach (var man in _snowmen) Effects.Puff(man.Center.X, man.Center.Y, 70 * man.S);
        foreach (var b in _balls) Effects.Puff(b.Position.X, b.Position.Y, b.Radius * 2.2);
        _snowmen.Clear();
        _balls.Clear();
        _drag = null;
        Sound.Play(SoundEffect.Whoosh, 0.3);
    }

    // ---- Window motion ----

    private void ObjectsFollow(LedgeMove move)
    {
        if (Math.Abs(move.Dx) <= 6) return;
        foreach (var man in _snowmen.Where(m => m.State == FigureState.Idle && m.Support?.Kind == move.Kind))
            man.AngleVelocity += Math.Clamp(-move.Dx * 0.08, -6, 6);
    }
}
