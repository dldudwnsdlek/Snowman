namespace Snowman.Core;

/// <summary>Point in scene coordinates (origin bottom-left, y up).</summary>
public readonly record struct PointD(double X, double Y)
{
    public static PointD operator +(PointD p, VectorD v) => new(p.X + v.Dx, p.Y + v.Dy);
    public double DistanceTo(PointD o) => Math.Sqrt((X - o.X) * (X - o.X) + (Y - o.Y) * (Y - o.Y));
}

public readonly record struct VectorD(double Dx, double Dy)
{
    public static readonly VectorD Zero = new(0, 0);
    public double Length => Math.Sqrt(Dx * Dx + Dy * Dy);
    public static VectorD operator *(VectorD v, double k) => new(v.Dx * k, v.Dy * k);
}

/// <summary>Rectangle; Y is the low edge in scene space.</summary>
public readonly record struct RectD(double X, double Y, double Width, double Height)
{
    public double MinX => X;
    public double MaxX => X + Width;
    public double MinY => Y;
    public double MaxY => Y + Height;
    public double MidX => X + Width / 2;
    public double MidY => Y + Height / 2;
    public bool Contains(PointD p) => p.X >= MinX && p.X < MaxX && p.Y >= MinY && p.Y < MaxY;
    public RectD Offset(double dx, double dy) => new(X + dx, Y + dy, Width, Height);
}
