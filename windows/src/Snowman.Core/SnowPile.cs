namespace Snowman.Core;

/// <summary>
/// Height map of snow lying on one ledge (window top, taskbar top or the screen bottom).
/// Heights are stored per 2pt column relative to the ledge's left end.
/// "Area" means snow volume in this 2D world: height × width.
/// </summary>
public sealed class SnowPile
{
    public const double ColumnWidth = 2;
    /// <summary>Largest height difference allowed between neighbouring columns (angle of repose).</summary>
    public const float MaxStep = 1.2f;
    /// <summary>Width over which capacity tapers down at each end, giving rounded snow caps.</summary>
    public const double TaperWidth = 10;

    private static readonly float[] Kernel = { 0.1f, 0.2f, 0.4f, 0.2f, 0.1f };

    private float[] _heights;
    private float _maxHeight;

    public SnowPile(double width, float maxHeight)
    {
        Width = Math.Max(width, ColumnWidth);
        _maxHeight = maxHeight;
        _heights = new float[Columns(width)];
    }

    private SnowPile(double width, float maxHeight, float[] heights)
    {
        Width = width;
        _maxHeight = maxHeight;
        _heights = heights;
    }

    public SnowPile Clone() => new(Width, _maxHeight, (float[])_heights.Clone());

    public float[] Heights => _heights;
    public double Width { get; private set; }
    public int ColumnCount => _heights.Length;

    public float MaxHeight
    {
        get => _maxHeight;
        set { _maxHeight = value; ClipToCapacity(); }
    }

    public float TotalArea
    {
        get
        {
            float s = 0;
            foreach (var h in _heights) s += h;
            return s * (float)ColumnWidth;
        }
    }

    public bool IsEmpty
    {
        get
        {
            foreach (var h in _heights) if (h >= 0.01f) return false;
            return true;
        }
    }

    public int? Column(double localX)
    {
        if (localX < 0 || localX >= Width) return null;
        return Math.Min(ColumnCount - 1, (int)(localX / ColumnWidth));
    }

    public double CenterX(int c) => Math.Min((c + 0.5) * ColumnWidth, Width);

    /// <summary>Maximum height a column may hold: full in the middle, lower toward both ends.</summary>
    public float Capacity(int c)
    {
        double center = CenterX(c);
        double d = Math.Min(center, Width - center);
        if (d >= TaperWidth) return _maxHeight;
        float t = (float)(Math.Max(0, d) / TaperWidth);
        float smooth = t * t * (3 - 2 * t);
        return _maxHeight * (0.35f + 0.65f * smooth);
    }

    /// <summary>Height at a local x, interpolated between column centres. 0 outside the ledge.</summary>
    public float HeightAt(double x)
    {
        if (x < 0 || x > Width || _heights.Length == 0) return 0;
        double pos = x / ColumnWidth - 0.5;
        int i0 = (int)Math.Floor(pos);
        float frac = (float)(pos - i0);
        float a = _heights[Math.Clamp(i0, 0, ColumnCount - 1)];
        float b = _heights[Math.Clamp(i0 + 1, 0, ColumnCount - 1)];
        return a + (b - a) * frac;
    }

    /// <summary>Adds snow centred on x, spread over five columns. Returns the area that did not fit.</summary>
    public float Add(double localX, float area)
    {
        if (area <= 0) return area;
        var col = Column(Math.Max(0, Math.Min(localX, Width - 0.001)));
        if (col is null) return area;
        int c = col.Value;
        float total = 0;
        for (int k = 0; k < Kernel.Length; k++)
        {
            int cc = c + k - 2;
            if (cc >= 0 && cc < ColumnCount) total += Kernel[k];
        }
        float overflow = 0;
        for (int k = 0; k < Kernel.Length; k++)
        {
            int cc = c + k - 2;
            if (cc < 0 || cc >= ColumnCount) continue;
            float gain = (Kernel[k] / total) * area / (float)ColumnWidth;
            float room = Math.Max(0, Capacity(cc) - _heights[cc]);
            float used = Math.Min(room, gain);
            _heights[cc] += used;
            overflow += (gain - used) * (float)ColumnWidth;
        }
        return overflow;
    }

    /// <summary>
    /// Lets snow settle: neighbours differ by at most MaxStep and snow beyond either end falls off.
    /// Returns the area spilled off each end.
    /// </summary>
    public (float Left, float Right) Relax(int iterations)
    {
        int n = ColumnCount;
        if (n == 0) return (0, 0);
        float step = MaxStep, colW = (float)ColumnWidth, left = 0, right = 0;
        for (int iter = 0; iter < iterations; iter++)
        {
            bool moved = false;
            if (_heights[0] > step)
            {
                float t = (_heights[0] - step) / 2;
                _heights[0] -= t; left += t * colW; moved = true;
            }
            if (_heights[n - 1] > step)
            {
                float t = (_heights[n - 1] - step) / 2;
                _heights[n - 1] -= t; right += t * colW; moved = true;
            }
            bool forward = iter % 2 == 0;
            for (int j = 0; j < n - 1; j++)
            {
                int i = forward ? j : (n - 2 - j);
                float d = _heights[i] - _heights[i + 1];
                if (Math.Abs(d) > step)
                {
                    float t = (Math.Abs(d) - step) / 2;
                    if (d > 0) { _heights[i] -= t; _heights[i + 1] += t; }
                    else { _heights[i] += t; _heights[i + 1] -= t; }
                    moved = true;
                }
            }
            for (int c = 0; c < n; c++)
            {
                float cap = Capacity(c);
                if (_heights[c] > cap)
                {
                    float excess = (_heights[c] - cap) * colW;
                    _heights[c] = cap;
                    if (c < n / 2) left += excess; else right += excess;
                    moved = true;
                }
            }
            if (!moved) break;
        }
        return (left, right);
    }

    /// <summary>Removes up to maxArea from the columns whose centres lie in [lo, hi]. Returns the area removed.</summary>
    public float Take(double lo, double hi, float maxArea)
    {
        if (maxArea <= 0 || ColumnCount == 0) return 0;
        int from = Math.Max(0, (int)Math.Floor(lo / ColumnWidth) - 1);
        int to = Math.Min(ColumnCount - 1, (int)Math.Ceiling(hi / ColumnWidth) + 1);
        float available = 0;
        for (int c = from; c <= to; c++)
        {
            double x = CenterX(c);
            if (x >= lo && x <= hi) available += _heights[c];
        }
        available *= (float)ColumnWidth;
        if (available <= 0) return 0;
        float taken = Math.Min(available, maxArea);
        float factor = 1 - taken / available;
        for (int c = from; c <= to; c++)
        {
            double x = CenterX(c);
            if (x >= lo && x <= hi) _heights[c] *= factor;
        }
        return taken;
    }

    public float TakeAll(double lo, double hi) => Take(lo, hi, float.MaxValue);

    /// <summary>Changes the width, spreading the same snow over it. Returns area that no longer fits.</summary>
    public float Resample(double newWidth)
    {
        newWidth = Math.Max(newWidth, ColumnWidth);
        if (newWidth == Width) return 0;
        float oldArea = TotalArea;
        int newCount = Columns(newWidth);
        var output = new float[newCount];
        double ratio = Width / newWidth;
        for (int i = 0; i < newCount; i++) output[i] = HeightAt((i + 0.5) * ColumnWidth * ratio);
        _heights = output;
        Width = newWidth;
        float newArea = TotalArea;
        if (newArea > 0)
        {
            float scale = oldArea / newArea;
            for (int i = 0; i < _heights.Length; i++) _heights[i] *= scale;
        }
        return ClipToCapacity();
    }

    public void Clear() => Array.Clear(_heights);

    /// <summary>Multiplies every height (melting, shaking snow off).</summary>
    public void Scale(float factor)
    {
        float f = Math.Max(0, factor);
        for (int i = 0; i < _heights.Length; i++) _heights[i] *= f;
    }

    private static int Columns(double width) => Math.Max(1, (int)Math.Ceiling(width / ColumnWidth));

    private float ClipToCapacity()
    {
        float overflow = 0;
        for (int c = 0; c < _heights.Length; c++)
        {
            float cap = Capacity(c);
            if (_heights[c] > cap)
            {
                overflow += (_heights[c] - cap) * (float)ColumnWidth;
                _heights[c] = cap;
            }
        }
        return overflow;
    }
}
