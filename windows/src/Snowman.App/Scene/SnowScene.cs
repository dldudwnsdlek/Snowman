using System;
using System.Collections.Generic;
using System.Linq;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>A ledge as seen during one frame.</summary>
internal sealed record FrameLedge(LedgeKind Kind, LedgeSpec Spec, Visibility Vis, int Columns);

/// <summary>Everything that happens on one monitor: snowfall, piles, snowballs, snowmen, the plow.</summary>
internal sealed partial class SnowScene
{
    private readonly Dictionary<LedgeKind, Visibility> _vis = new();
    private readonly Dictionary<LedgeKind, PileRenderer> _renderers = new();
    private readonly Dictionary<LedgeKind, (float Left, float Right)> _spill = new();
    private readonly HashSet<LedgeKind> _touched = new();
    private readonly LandDelegate _land;
    private List<FrameLedge> _ledges = new();
    private double _spawnCarry;
    private double _meltUntil;
    private double _lastApply;
    private int _frame;
    private bool _prepopulated;

    public SnowScene(double width, double height)
    {
        Width = width;
        Height = height;
        _land = Land;
    }

    public double Width { get; private set; }
    public double Height { get; private set; }
    public PileStore Store { get; } = new();
    public ParticleSystem Particles { get; } = new();
    public EffectSystem Effects { get; } = new();
    public SnowAmount Amount { get; set; } = SnowAmount.Normal;
    public bool Snowing { get; set; } = true;
    public bool AccumulateOnWindows { get; set; } = true;
    public double GraceUntil { get; set; }
    public Func<LedgeKind, bool>? KeepAway { get; set; }
    /// <summary>True while the overlay must receive mouse events (hovering or dragging something).</summary>
    public bool WantsMouse { get; private set; }
    /// <summary>Cursor in scene coordinates, or null when it is on another monitor.</summary>
    public PointD? Mouse { get; set; }
    public double SimTime { get; private set; }
    public IReadOnlyList<FrameLedge> FrameLedges => _ledges;
    /// <summary>Set when a re-apply of window positions is needed (resize, toggles).</summary>
    public bool NeedsApply { get; set; } = true;

    public void Resize(double width, double height)
    {
        if (Math.Abs(width - Width) < 0.5 && Math.Abs(height - Height) < 0.5) return;
        Width = width;
        Height = height;
        NeedsApply = true;
    }

    private void Prepopulate()
    {
        _prepopulated = true;
        if (!Snowing) return;
        int count = (int)(Amount.FlakesPerSecond() * (Width / 1512) * 7);
        for (int i = 0; i < count; i++)
            Particles.SpawnFlake(Random.Shared.NextDouble() * (Width + 40) - 20, Height * (0.15 + Random.Shared.NextDouble() * 0.85) + 10, Amount);
    }

    // ---- Ledges ----

    public void Apply(IReadOnlyList<(long Id, RectD Frame)> windows, RectD? taskbar, double now)
    {
        NeedsApply = false;
        var specs = Ledges.Build(windows, taskbar, Width, Height, 0, AccumulateOnWindows);
        var oldSpecs = Store.Specs;
        double dt = Math.Max(1.0 / 120, now - _lastApply);
        _lastApply = now;
        var result = Store.Sync(specs, now, GraceUntil, KeepAway);
        foreach (var d in result.Dropped) DropPile(d.Spec, d.Pile);

        var live = new HashSet<LedgeKind>();
        foreach (var spec in specs)
        {
            live.Add(spec.Kind);
            if (!_renderers.TryGetValue(spec.Kind, out var renderer))
            {
                renderer = new PileRenderer();
                _renderers[spec.Kind] = renderer;
            }
            oldSpecs.TryGetValue(spec.Kind, out var old);
            if (!spec.SameAs(old) || !_vis.ContainsKey(spec.Kind))
            {
                _vis[spec.Kind] = Ledges.VisibilityOf(spec, Store.Piles[spec.Kind].ColumnCount);
                renderer.Dirty = true;
            }
        }
        foreach (var kind in _renderers.Keys.Where(k => !live.Contains(k)).ToList())
        {
            _renderers.Remove(kind);
            _vis.Remove(kind);
        }
        _ledges = specs.Where(s => _vis.ContainsKey(s.Kind) && Store.Piles.ContainsKey(s.Kind))
                       .Select(s => new FrameLedge(s.Kind, s, _vis[s.Kind], Store.Piles[s.Kind].ColumnCount)).ToList();
        foreach (var m in result.Moved)
        {
            ShakeOff(m, Math.Sqrt(m.Dx * m.Dx + m.Dy * m.Dy) / dt);
            ObjectsFollow(m);
        }
    }

    public FrameLedge? Ledge(LedgeKind kind)
    {
        foreach (var l in _ledges) if (l.Kind == kind) return l;
        return null;
    }

    public void MarkDirty(LedgeKind kind)
    {
        if (_renderers.TryGetValue(kind, out var r)) r.Dirty = true;
        _touched.Add(kind);
    }

    /// <summary>Snow surface height at x on a ledge, or null when that spot is hidden.</summary>
    public double? SurfaceY(FrameLedge l, double x)
    {
        if (x < l.Spec.X0 || x >= l.Spec.X1 || !Store.Piles.TryGetValue(l.Kind, out var pile)) return null;
        int c = Math.Clamp((int)((x - l.Spec.X0) / SnowPile.ColumnWidth), 0, l.Columns - 1);
        if (l.Vis.Hidden[c]) return null;
        return l.Spec.Y + Math.Min(pile.HeightAt(x - l.Spec.X0), l.Vis.Ceiling[c]);
    }

    /// <summary>Highest visible surface at or below y for horizontal position x.</summary>
    public (FrameLedge Ledge, double Y)? SurfaceBelow(double x, double y)
    {
        (FrameLedge, double)? best = null;
        foreach (var l in _ledges)
        {
            if (SurfaceY(l, x) is not double s || s > y + 0.5) continue;
            if (best is null || s > best.Value.Item2) best = (l, s);
        }
        return best;
    }

    // ---- Falling snow ----

    private void DropPile(LedgeSpec spec, SnowPile pile)
    {
        float total = pile.TotalArea;
        if (total <= 1) return;
        float perClump = Math.Max(4, total / 520);
        for (int c = 0; c < pile.ColumnCount; c++)
        {
            float h = pile.Heights[c];
            if (h <= 0.15f) continue;
            float area = h * (float)SnowPile.ColumnWidth;
            while (area > 0.5f)
            {
                float take = Math.Min(area, perClump * (0.6f + Random.Shared.NextSingle() * 0.8f));
                area -= take;
                Particles.SpawnClump(spec.X0 + pile.CenterX(c) + Random.Shared.NextDouble() * 2 - 1, spec.Y + Random.Shared.NextDouble() * h,
                                     Random.Shared.NextDouble() * 56 - 28, Random.Shared.NextDouble() * 60 - 20, take);
            }
        }
        Sound.Play(SoundEffect.Whoosh);
    }

    private void ShakeOff(LedgeMove move, double speed)
    {
        if (!move.Kind.IsWindow || speed <= 900 || !Store.Piles.TryGetValue(move.Kind, out var pile) || Ledge(move.Kind) is not FrameLedge l) return;
        float fraction = (float)Math.Min(0.25, speed / 900 * 0.06);
        for (int c = 0; c < pile.ColumnCount; c += 3)
        {
            float h = pile.Heights[c];
            if (h <= 0.5f) continue;
            float area = h * fraction * (float)SnowPile.ColumnWidth * 3;
            if (area > 0.8f)
                Particles.SpawnClump(l.Spec.X0 + pile.CenterX(c), l.Spec.Y + h * 0.6, -move.Dx * 3 + Random.Shared.NextDouble() * 40 - 20,
                                     Random.Shared.NextDouble() * 40, area);
        }
        pile.Scale(1 - fraction);
        MarkDirty(move.Kind);
    }

    private bool Land(ref Particle p)
    {
        foreach (var l in _ledges)
        {
            if (p.X < l.Spec.X0 || p.X >= l.Spec.X1) continue;
            if (p.PrevY < l.Spec.Y || p.Y > l.Spec.Y + l.Spec.MaxHeight + 1) continue;
            double local = p.X - l.Spec.X0;
            int c = Math.Clamp((int)(local / SnowPile.ColumnWidth), 0, l.Columns - 1);
            if (l.Vis.Hidden[c] || !Store.Piles.TryGetValue(l.Kind, out var pile)) continue;
            float h = pile.Heights[c];
            if (h >= l.Vis.Ceiling[c]) continue;
            if (!Physics.Crossed(p.PrevY, p.Y, l.Spec.Y + h)) continue;
            float probability = p.IsClump ? Math.Max(0.75f, l.Spec.LandProbability) : l.Spec.LandProbability;
            if (Random.Shared.NextSingle() < probability)
            {
                pile.Add(local, p.Area);
                MarkDirty(l.Kind);
                return true;
            }
        }
        return false;
    }

    // ---- Frame ----

    public void Update(double dt, double now)
    {
        if (!_prepopulated) Prepopulate();
        SimTime += dt;
        _frame++;
        if (Snowing)
        {
            _spawnCarry += Amount.FlakesPerSecond() * (Width / 1512) * dt;
            while (_spawnCarry >= 1)
            {
                _spawnCarry -= 1;
                Particles.SpawnFlake(Random.Shared.NextDouble() * (Width + 80) - 40, Height + 8, Amount);
            }
        }
        double wind = Amount.WindStrength() * (0.6 * Math.Sin(SimTime * 0.11) + 0.4 * Math.Sin(SimTime * 0.37 + 1.3));
        Particles.Update(dt, wind, Width, _land);
        SettlePiles(now, dt);
        UpdateObjects(dt);
        Effects.Update(dt);
    }

    private void SettlePiles(double now, double dt)
    {
        if (_meltUntil != 0)
        {
            if (now < _meltUntil)
            {
                float factor = (float)Math.Pow(0.004, dt / 0.6);
                foreach (var p in Store.Piles.Values) p.Scale(factor);
            }
            else
            {
                Store.ClearAll();
                _meltUntil = 0;
            }
            foreach (var kind in Store.Piles.Keys) MarkDirty(kind);
        }
        var kinds = _frame % 20 == 0 ? Store.Piles.Keys.ToList() : _touched.ToList();
        _touched.Clear();
        foreach (var kind in kinds)
        {
            if (!Store.Piles.TryGetValue(kind, out var pile) || Ledge(kind) is not FrameLedge l) continue;
            var (left, right) = pile.Relax(3);
            if (left > 0 || right > 0) { if (_renderers.TryGetValue(kind, out var r)) r.Dirty = true; }
            _spill.TryGetValue(kind, out var s);
            s.Left += left;
            s.Right += right;
            if (s.Left > 3)
            {
                Particles.SpawnClump(l.Spec.X0 + 1, l.Spec.Y + 2, -(10 + Random.Shared.NextDouble() * 20), 0, s.Left);
                s.Left = 0;
            }
            if (s.Right > 3)
            {
                Particles.SpawnClump(l.Spec.X1 - 1, l.Spec.Y + 2, 10 + Random.Shared.NextDouble() * 20, 0, s.Right);
                s.Right = 0;
            }
            _spill[kind] = s;
        }
        foreach (var (kind, renderer) in _renderers)
        {
            if (Store.Piles.TryGetValue(kind, out var pile) && _vis.TryGetValue(kind, out var vis)) renderer.Rebuild(pile, vis, now);
        }
    }

    // ---- Commands ----

    public void ClearSnow(double now) => _meltUntil = now + 0.6;

    public void NoteDesktopSwitch(double now) => GraceUntil = now + 0.8;
}
