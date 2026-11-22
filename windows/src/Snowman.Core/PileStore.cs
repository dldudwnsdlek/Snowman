namespace Snowman.Core;

public sealed record DroppedPile(LedgeSpec Spec, SnowPile Pile);

public readonly record struct LedgeMove(LedgeKind Kind, double Dx, double Dy);

public sealed class SyncResult
{
    /// <summary>Ledges that went away for good: their snow should fall.</summary>
    public List<DroppedPile> Dropped { get; } = new();
    /// <summary>Ledges that are still here but moved since the last sync.</summary>
    public List<LedgeMove> Moved { get; } = new();
}

/// <summary>Owns the snow piles of one screen and keeps them matched to the current ledges.</summary>
public sealed class PileStore
{
    public Dictionary<LedgeKind, SnowPile> Piles { get; } = new();
    public Dictionary<LedgeKind, LedgeSpec> Specs { get; private set; } = new();
    /// <summary>Piles whose ledge went away temporarily (virtual desktop switch, auto-hidden taskbar).</summary>
    public Dictionary<LedgeKind, SnowPile> Stash { get; } = new();

    /// <param name="keepAway">Returns true for a vanished ledge that is only hidden for now (stash it).</param>
    public SyncResult Sync(IReadOnlyList<LedgeSpec> newSpecs, double now, double graceUntil, Func<LedgeKind, bool>? keepAway = null)
    {
        var result = new SyncResult();
        var newKinds = new HashSet<LedgeKind>(newSpecs.Select(s => s.Kind));
        foreach (var (kind, oldSpec) in Specs)
        {
            if (newKinds.Contains(kind)) continue;
            if (!Piles.Remove(kind, out var pile)) continue;
            if (kind.Type == LedgeType.Taskbar || now < graceUntil || (keepAway?.Invoke(kind) ?? false)) Stash[kind] = pile;
            else if (!pile.IsEmpty) result.Dropped.Add(new DroppedPile(oldSpec, pile));
        }

        var map = new Dictionary<LedgeKind, LedgeSpec>();
        foreach (var spec in newSpecs)
        {
            map[spec.Kind] = spec;
            SnowPile? pile = null;
            if (Piles.TryGetValue(spec.Kind, out var existing)) pile = existing;
            else if (Stash.Remove(spec.Kind, out var stashed)) pile = stashed;
            if (pile is null)
            {
                Piles[spec.Kind] = new SnowPile(spec.Width, spec.MaxHeight);
                continue;
            }
            if (Specs.TryGetValue(spec.Kind, out var old))
            {
                double dx = spec.X0 - old.X0, dy = spec.Y - old.Y;
                if (dx != 0 || dy != 0) result.Moved.Add(new LedgeMove(spec.Kind, dx, dy));
            }
            if (Math.Abs(pile.Width - spec.Width) > 0.5) pile.Resample(spec.Width);
            if (pile.MaxHeight != spec.MaxHeight) pile.MaxHeight = spec.MaxHeight;
            Piles[spec.Kind] = pile;
        }
        Specs = map;
        return result;
    }

    /// <summary>Removes snow everywhere, including stashed piles.</summary>
    public void ClearAll()
    {
        foreach (var p in Piles.Values) p.Clear();
        Stash.Clear();
    }

    public void ClearStash(LedgeKind kind) => Stash.Remove(kind);
}
