using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App.Scene;

internal enum FigureState { Building, Idle, Dragged, Flying }

/// <summary>A living snowman built from the art parts. Its position is the ground contact point.</summary>
internal sealed class SnowmanFigure
{
    private static readonly (double X, double Y) Neck = (0, 50);
    private static readonly (double X, double Y) Pivot = (0, 45);
    private static readonly HashSet<SnowmanPart> UpperParts = new()
    {
        SnowmanPart.Head, SnowmanPart.Eyes, SnowmanPart.EyesClosed, SnowmanPart.Nose, SnowmanPart.Mouth, SnowmanPart.Cheeks, SnowmanPart.Hat,
    };

    private readonly Dictionary<SnowmanPart, (BitmapSource Bitmap, PartImage Info)> _parts;
    private readonly List<SnowmanPart> _order;
    private readonly HashSet<SnowmanPart> _hiddenParts = new();
    private readonly Dictionary<SnowmanPart, double> _appear = new();
    private readonly List<(double At, Action Do)> _schedule = new();
    private readonly double _phase = Random.Shared.NextDouble() * 10;
    private double _nextBlink, _blinkUntil, _waveStart = -10, _waveUntil, _nextWave, _danceStart = -10, _danceUntil, _nextDance;
    private bool _started, _danceSoon, _eyesShown, _closed;
    private double _rigX = 1, _rigY = 1, _bob, _hop, _leftArm, _rightArm, _tail;

    public SnowmanFigure(int id, SnowmanStyle style, double bodyRadius)
    {
        Id = id;
        Style = style;
        S = Math.Max(0.3, bodyRadius / SnowmanArt.BodyRadius);
        _parts = Sprites.PartsFor(style);
        _order = _parts.Keys.OrderBy(p => _parts[p].Info.Z).ToList();
    }

    public int Id { get; }
    public SnowmanStyle Style { get; }
    /// <summary>Body radius / 30 (reference body radius).</summary>
    public double S { get; }
    public FigureState State { get; set; } = FigureState.Building;
    public VectorD Velocity { get; set; }
    public double Spin { get; set; }
    public Support? Support { get; set; }
    public PointD Position { get; set; }
    public PointD DragTarget { get; set; }
    public bool DanceAfterLanding { get; set; }
    public bool Hidden { get; set; }
    /// <summary>Rotation around the body's middle (tilt while dragged, spin while flying, wobble).</summary>
    public double Angle { get; set; }
    public double AngleVelocity { get; set; }

    public RectD HitFrame => new(Position.X - 34 * S, Position.Y, 68 * S, 112 * S);
    public PointD Center => new(Position.X, Position.Y + 50 * S);
    public double HalfWidth => 30 * S;
    public double HalfHeight => 55 * S;
    public IReadOnlyDictionary<SnowmanPart, (BitmapSource Bitmap, PartImage Info)> Parts => _parts;

    /// <summary>Hides everything except the two balls, then adds pieces one by one (0.3 s apart).</summary>
    public void PlayBuildSequence(double now, EffectSystem fx, Action? done = null)
    {
        State = FigureState.Building;
        var groups = new[]
        {
            new[] { SnowmanPart.LeftArm, SnowmanPart.RightArm }, new[] { SnowmanPart.Eyes }, new[] { SnowmanPart.Nose },
            new[] { SnowmanPart.Mouth, SnowmanPart.Cheeks }, new[] { SnowmanPart.Buttons, SnowmanPart.Scarf, SnowmanPart.ScarfTail },
            new[] { SnowmanPart.Hat },
        };
        foreach (var g in groups) foreach (var p in g) _hiddenParts.Add(p);
        _eyesShown = false;
        _schedule.Add((now, () =>
        {
            fx.Sparkles(Center.X, Center.Y, 50 * S, 7);
            Sound.Play(SoundEffect.Tink);
        }));
        double t = now + 0.3;
        foreach (var g in groups)
        {
            var group = g;
            double at = t;
            _schedule.Add((at, () =>
            {
                foreach (var p in group) Pop(p, at);
                Sound.Play(SoundEffect.Pop, 0.25);
            }));
            t += 0.3;
        }
        _schedule.Add((t, () =>
        {
            State = FigureState.Idle;
            fx.Sparkles(Position.X, Position.Y + 100 * S, 30 * S, 5);
            Sound.Play(SoundEffect.Done, 0.3);
            _danceSoon = true;
            done?.Invoke();
        }));
    }

    private void Pop(SnowmanPart p, double at)
    {
        if (p == SnowmanPart.Eyes) _eyesShown = true;
        _hiddenParts.Remove(p);
        _appear[p] = at;
    }

    public void FinishInstantly()
    {
        _schedule.Clear();
        _hiddenParts.Clear();
        _appear.Clear();
        _eyesShown = true;
        State = FigureState.Idle;
    }

    public void Wave(double t)
    {
        if (t <= _waveUntil + 1.5) return;
        _waveStart = t;
        _waveUntil = t + 1.6;
    }

    public void Dance(double t)
    {
        _danceStart = t;
        _danceUntil = t + 3.0;
    }

    /// <summary>Breathing, blinking, waving, dancing and wobble.</summary>
    public void Animate(double t, double dt, PointD? mouse)
    {
        for (int i = 0; i < _schedule.Count;)
        {
            if (_schedule[i].At <= t)
            {
                var action = _schedule[i].Do;
                _schedule.RemoveAt(i);
                action();
            }
            else i++;
        }
        if (!_started)
        {
            _started = true;
            _nextBlink = t + 1 + Random.Shared.NextDouble() * 3;
            _nextWave = t + 4 + Random.Shared.NextDouble() * 6;
            _nextDance = t + 14 + Random.Shared.NextDouble() * 14;
        }
        if (_danceSoon)
        {
            _danceStart = t;
            _danceUntil = t + 2.4;
            _danceSoon = false;
        }
        double breath = Math.Sin((t + _phase) * 2 * Math.PI / 2.8);
        _rigY = 1 + 0.024 * breath;
        _rigX = 1 - 0.01 * breath;
        _bob = 0.9 * breath;
        if (t > _nextBlink)
        {
            _blinkUntil = t + 0.13;
            _nextBlink = t + 2 + Random.Shared.NextDouble() * 4;
        }
        _closed = t < _blinkUntil && Style != SnowmanStyle.Elf;

        if (State != FigureState.Idle)
        {
            _leftArm = State == FigureState.Flying ? 0.5 * Math.Sin(t * 18) : 0.25;
            _rightArm = State == FigureState.Flying ? -0.5 * Math.Sin(t * 18) : -0.25;
            _hop = 0;
            return;
        }
        if (mouse is PointD m && m.DistanceTo(Center) < 150 * Math.Max(1, S)) Wave(t);
        if (t > _nextWave) { Wave(t); _nextWave = t + 7 + Random.Shared.NextDouble() * 7; }
        if (t > _nextDance) { Dance(t); _nextDance = t + 16 + Random.Shared.NextDouble() * 16; }

        double left = 0.05 * Math.Sin(t * 1.3 + _phase), right = -0.05 * Math.Sin(t * 1.3 + _phase), hop = 0;
        if (t < _danceUntil)
        {
            double k = t - _danceStart;
            double beat = Math.Sin(k * 8);
            Angle = beat * 0.15;
            AngleVelocity = 0;
            hop = Math.Abs(Math.Sin(k * 8)) * 7;
            left = -0.45 + beat * 0.55;
            right = 0.45 + beat * 0.55;
        }
        else
        {
            AngleVelocity += (-60 * Angle - 9 * AngleVelocity) * dt;
            Angle += AngleVelocity * dt;
        }
        if (t < _waveUntil)
        {
            double k = t - _waveStart;
            right = 0.6 + Math.Sin(k * 13) * 0.4;
        }
        _leftArm = left;
        _rightArm = right;
        _tail = 0.08 * Math.Sin(t * 2.1 + _phase) - Angle * 0.5;
        _hop = hop;
    }

    /// <summary>Normalises the angle after a spin so the wobble settles the short way round.</summary>
    public void SettleUpright()
    {
        double a = Angle % (2 * Math.PI);
        if (a > Math.PI) a -= 2 * Math.PI;
        if (a < -Math.PI) a += 2 * Math.PI;
        Angle = a;
        AngleVelocity = 0;
    }

    /// <summary>Scene position of a part's anchor (for debris).</summary>
    public PointD PartPosition(SnowmanPart part)
    {
        var info = _parts[part].Info;
        bool upper = UpperParts.Contains(part);
        var local = new System.Windows.Point(info.PosX - (upper ? Neck.X : 0), info.PosY - (upper ? Neck.Y : 0));
        var m = upper ? Matrix.Multiply(UpperMatrix(), RigMatrix()) : RigMatrix();
        m = Matrix.Multiply(m, WorldMatrix());
        var p = m.Transform(local);
        return new PointD(p.X, p.Y);
    }

    public bool IsPartVisible(SnowmanPart part) => _parts.ContainsKey(part) && !_hiddenParts.Contains(part);

    private Matrix WorldMatrix() => SpriteDraw.Node(S, S, 0, Position.X, Position.Y);

    private Matrix RigMatrix()
    {
        double c = Math.Cos(Angle), s = Math.Sin(Angle);
        double rx = Pivot.X - (Pivot.X * c - Pivot.Y * s);
        double ry = Pivot.Y - (Pivot.X * s + Pivot.Y * c) + _hop;
        return SpriteDraw.Node(_rigX, _rigY, Angle, rx, ry);
    }

    private Matrix UpperMatrix() => SpriteDraw.Node(1, 1, 0, Neck.X, Neck.Y + _bob);

    private static double PopScale(double e) =>
        e < 0 ? 0 : e < 0.12 ? 1.25 * (1 - (1 - e / 0.12) * (1 - e / 0.12)) : e < 0.21 ? 1.25 - 0.25 * ((e - 0.12) / 0.09) : 1;

    private static double DropOffset(double e) =>
        e < 0.22 ? 46 * (1 - (e / 0.22) * (e / 0.22)) : e < 0.29 ? 4 * ((e - 0.22) / 0.07) : e < 0.36 ? 4 * (1 - (e - 0.29) / 0.07) : 0;

    public void Draw(DrawingContext dc, double t)
    {
        if (Hidden) return;
        var world = WorldMatrix();
        var rig = Matrix.Multiply(RigMatrix(), world);
        var upper = Matrix.Multiply(UpperMatrix(), rig);
        foreach (var part in _order)
        {
            if (_hiddenParts.Contains(part)) continue;
            if (part == SnowmanPart.Eyes && (!_eyesShown || _closed)) continue;
            if (part == SnowmanPart.EyesClosed && (!_eyesShown || !_closed)) continue;
            var (bmp, info) = _parts[part];
            double scale = 1, alpha = 1, dy = 0;
            if (_appear.TryGetValue(part, out double at))
            {
                double e = t - at;
                if (part == SnowmanPart.Hat)
                {
                    dy = DropOffset(e);
                    alpha = Math.Clamp(e / 0.12, 0, 1);
                }
                else scale = PopScale(e);
                if (e > 0.4) _appear.Remove(part);
            }
            double rot = part switch
            {
                SnowmanPart.LeftArm => _leftArm,
                SnowmanPart.RightArm => _rightArm,
                SnowmanPart.ScarfTail => _tail,
                _ => 0,
            };
            bool isUpper = UpperParts.Contains(part);
            double px = info.PosX - (isUpper ? Neck.X : 0);
            double py = info.PosY - (isUpper ? Neck.Y : 0) + dy;
            var local = SpriteDraw.Local(info.Width, info.Height, info.AnchorX, info.AnchorY, scale, scale, rot, px, py);
            var m = Matrix.Multiply(local, isUpper ? upper : rig);
            SpriteDraw.Image(dc, bmp, info.Width, info.Height, m, alpha);
        }
    }
}
