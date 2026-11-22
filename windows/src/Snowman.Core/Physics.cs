namespace Snowman.Core;

/// <summary>눈 양: 조금 / 보통 / 펑펑</summary>
public enum SnowAmount { Light, Normal, Heavy }

public static class SnowAmountInfo
{
    public static readonly SnowAmount[] All = { SnowAmount.Light, SnowAmount.Normal, SnowAmount.Heavy };

    public static double FlakesPerSecond(this SnowAmount a) => a switch
    {
        SnowAmount.Light => 15,
        SnowAmount.Normal => 45,
        _ => 130,
    };

    /// <summary>Flake diameter range in points.</summary>
    public static (double Min, double Max) SizeRange(this SnowAmount a) => a switch
    {
        SnowAmount.Light => (1.6, 3.4),
        SnowAmount.Normal => (1.6, 4.4),
        _ => (2.0, 6.0),
    };

    public static double WindStrength(this SnowAmount a) => a switch
    {
        SnowAmount.Light => 4,
        SnowAmount.Normal => 8,
        _ => 22,
    };

    public static string Title(this SnowAmount a) => a switch
    {
        SnowAmount.Light => "조금",
        SnowAmount.Normal => "보통",
        _ => "펑펑",
    };

    public static string Key(this SnowAmount a) => a switch
    {
        SnowAmount.Light => "light",
        SnowAmount.Normal => "normal",
        _ => "heavy",
    };

    public static SnowAmount? FromKey(string key) => All.Cast<SnowAmount?>().FirstOrDefault(a => a!.Value.Key() == key);
}

public static class SnowballTuning
{
    public const float ScoopMinimumHeight = 3;
    public const double StartRadius = 6;
    public const double MaxRadius = 56;
    public const double GrowthGain = 1.5;
}

public enum ImpactLevel { Soft, Crash, Shatter }

public enum WallSide { Left, Right, Top }

public static class ThrowTuning
{
    public const double CrashSpeed = 700;
    public const double ShatterSpeed = 2200;
    public const double WallRestitution = 0.55;
    public const double Gravity = -1800;
}

public static class Physics
{
    /// <summary>True when something moving down passes through surfaceY during this step.</summary>
    public static bool Crossed(double prevY, double newY, double surfaceY) => prevY >= surfaceY && newY < surfaceY;

    /// <summary>Radius after rolling up area pt² of snow.</summary>
    public static double GrownRadius(double r, double area) =>
        Math.Min(SnowballTuning.MaxRadius, Math.Sqrt(r * r + SnowballTuning.GrowthGain * Math.Max(0, area) / Math.PI));

    public static ImpactLevel Impact(double speed) =>
        speed >= ThrowTuning.ShatterSpeed ? ImpactLevel.Shatter : speed >= ThrowTuning.CrashSpeed ? ImpactLevel.Crash : ImpactLevel.Soft;

    /// <summary>Reflects a body off the left, right and top edges of bounds. Returns the wall and impact speed.</summary>
    public static (WallSide Side, double Speed)? BounceOffWalls(ref PointD position, ref VectorD velocity, double halfWidth,
                                                              double halfHeight, RectD bounds, double restitution)
    {
        if (position.X - halfWidth < bounds.MinX && velocity.Dx < 0)
        {
            double speed = -velocity.Dx;
            position = position with { X = bounds.MinX + halfWidth };
            velocity = velocity with { Dx = speed * restitution };
            return (WallSide.Left, speed);
        }
        if (position.X + halfWidth > bounds.MaxX && velocity.Dx > 0)
        {
            double speed = velocity.Dx;
            position = position with { X = bounds.MaxX - halfWidth };
            velocity = velocity with { Dx = -speed * restitution };
            return (WallSide.Right, speed);
        }
        if (position.Y + halfHeight > bounds.MaxY && velocity.Dy > 0)
        {
            double speed = velocity.Dy;
            position = position with { Y = bounds.MaxY - halfHeight };
            velocity = velocity with { Dy = -speed * restitution };
            return (WallSide.Top, speed);
        }
        return null;
    }

    /// <summary>The resting snowball a dropped ball should stack on, if any.</summary>
    public static int? StackCandidate(PointD droppedCenter, double droppedRadius, IEnumerable<(int Id, PointD Center, double Radius)> resting)
    {
        double bottom = droppedCenter.Y - droppedRadius;
        foreach (var r in resting)
        {
            if (Math.Abs(droppedCenter.X - r.Center.X) <= 0.75 * r.Radius && Math.Abs(bottom - (r.Center.Y + r.Radius)) <= 12)
                return r.Id;
        }
        return null;
    }
}

/// <summary>The five snowman looks.</summary>
public enum SnowmanStyle { Santa, Beanie, Gentleman, Earmuffs, Elf }

public static class SnowmanStyleInfo
{
    public static readonly SnowmanStyle[] All =
        { SnowmanStyle.Santa, SnowmanStyle.Beanie, SnowmanStyle.Gentleman, SnowmanStyle.Earmuffs, SnowmanStyle.Elf };

    public static string Title(this SnowmanStyle s) => s switch
    {
        SnowmanStyle.Santa => "산타",
        SnowmanStyle.Beanie => "비니",
        SnowmanStyle.Gentleman => "신사",
        SnowmanStyle.Earmuffs => "귀마개",
        _ => "요정",
    };
}

/// <summary>Deals the five styles in shuffled rounds so every look shows up evenly.</summary>
public sealed class StyleBag
{
    private readonly SeededGenerator _rng;
    private readonly Queue<SnowmanStyle> _queue = new();
    private SnowmanStyle? _last;

    public StyleBag(ulong? seed = null)
    {
        _rng = new SeededGenerator(seed ?? (ulong)Random.Shared.NextInt64(1, long.MaxValue));
    }

    public SnowmanStyle Next()
    {
        if (_queue.Count == 0)
        {
            var round = SnowmanStyleInfo.All.ToArray();
            for (int i = round.Length - 1; i > 0; i--)
            {
                int j = (int)(_rng.Unit() * (i + 1));
                (round[i], round[j]) = (round[j], round[i]);
            }
            if (round[0] == _last) (round[0], round[^1]) = (round[^1], round[0]);
            foreach (var s in round) _queue.Enqueue(s);
        }
        var style = _queue.Dequeue();
        _last = style;
        return style;
    }
}

/// <summary>Small deterministic RNG (SplitMix64) for reproducible art and tests.</summary>
public sealed class SeededGenerator
{
    private ulong _state;

    public SeededGenerator(ulong seed) { _state = unchecked(seed + 0x9E3779B97F4A7C15UL); }

    public ulong Next()
    {
        unchecked
        {
            _state += 0x9E3779B97F4A7C15UL;
            ulong z = _state;
            z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
            z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
            return z ^ (z >> 31);
        }
    }

    public double Unit() => (Next() >> 11) / (double)(1UL << 53);
    public double Range(double lo, double hi) => lo + (hi - lo) * Unit();
    public float RangeF(double lo, double hi) => (float)Range(lo, hi);
}
