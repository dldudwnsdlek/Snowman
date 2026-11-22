using SkiaSharp;

namespace Snowman.Art;

/// <summary>Colour helpers.</summary>
public static class Col
{
    public static SKColor Hex(uint v, double alpha = 1) =>
        new((byte)((v >> 16) & 0xFF), (byte)((v >> 8) & 0xFF), (byte)(v & 0xFF), (byte)Math.Round(Math.Clamp(alpha, 0, 1) * 255));

    public static SKColor Mix(SKColor a, SKColor b, double t)
    {
        t = Math.Clamp(t, 0, 1);
        byte L(byte x, byte y) => (byte)Math.Round(x + (y - x) * t);
        return new SKColor(L(a.Red, b.Red), L(a.Green, b.Green), L(a.Blue, b.Blue), L(a.Alpha, b.Alpha));
    }
}

/// <summary>
/// Drawing helpers. All art is drawn in y-up coordinates (origin bottom-left) like the macOS version;
/// <see cref="Image"/> sets up the flip so pixels come out the right way round.
/// </summary>
public static class Draw
{
    public static SKPoint P(double x, double y) => new((float)x, (float)y);

    public static SKSurface NewSurface(int w, int h) =>
        SKSurface.Create(new SKImageInfo(w, h, SKColorType.Bgra8888, SKAlphaType.Premul))
        ?? throw new InvalidOperationException("Could not create drawing surface");

    /// <summary>Transparent image of width×height points at scale pixels per point, drawn y-up.</summary>
    public static SKImage Image(double width, double height, double scale, Action<SKCanvas> draw)
    {
        int w = Math.Max(1, (int)Math.Ceiling(width * scale));
        int h = Math.Max(1, (int)Math.Ceiling(height * scale));
        using var surface = NewSurface(w, h);
        var c = surface.Canvas;
        c.Clear(SKColors.Transparent);
        c.Translate(0, h);
        c.Scale((float)scale, (float)-scale);
        draw(c);
        c.Flush();
        return surface.Snapshot();
    }

    public static readonly SKPaint Smooth = new() { FilterQuality = SKFilterQuality.High, IsAntialias = true };

    public static void FillLinear(this SKCanvas c, SKColor[] colors, float[]? pos, SKPoint from, SKPoint to)
    {
        using var shader = SKShader.CreateLinearGradient(from, to, colors, pos, SKShaderTileMode.Clamp);
        using var p = new SKPaint { Shader = shader, IsAntialias = true };
        c.DrawPaint(p);
    }

    /// <summary>Radial gradient. With extend=false only the disc itself is painted.</summary>
    public static void FillRadial(this SKCanvas c, SKColor[] colors, float[]? pos, SKPoint center, float radius,
                                  SKPoint? startCenter = null, float startRadius = 0, bool extend = true)
    {
        var mode = extend ? SKShaderTileMode.Clamp : SKShaderTileMode.Decal;
        using var shader = startCenter is SKPoint s
            ? SKShader.CreateTwoPointConicalGradient(s, startRadius, center, radius, colors, pos, mode)
            : SKShader.CreateRadialGradient(center, radius, colors, pos, mode);
        using var p = new SKPaint { Shader = shader, IsAntialias = true };
        if (extend) c.DrawPaint(p);
        else c.DrawCircle(center, radius, p);
    }

    public static void Clipped(this SKCanvas c, SKPath path, Action body)
    {
        c.Save();
        c.ClipPath(path, SKClipOperation.Intersect, true);
        body();
        c.Restore();
    }

    public static void Clipped(this SKCanvas c, SKRect rect, Action body)
    {
        c.Save();
        c.ClipRect(rect, SKClipOperation.Intersect, true);
        body();
        c.Restore();
    }

    public static void Fill(this SKCanvas c, SKPath path, SKColor color)
    {
        using var p = new SKPaint { Color = color, IsAntialias = true, Style = SKPaintStyle.Fill };
        c.DrawPath(path, p);
    }

    public static void Stroke(this SKCanvas c, SKPath path, SKColor color, double width,
                              SKStrokeCap cap = SKStrokeCap.Round, SKStrokeJoin join = SKStrokeJoin.Round)
    {
        using var p = new SKPaint
        {
            Color = color, IsAntialias = true, Style = SKPaintStyle.Stroke, StrokeWidth = (float)width, StrokeCap = cap, StrokeJoin = join,
        };
        c.DrawPath(path, p);
    }

    public static void Circle(this SKCanvas c, double x, double y, double r, SKColor color)
    {
        using var p = new SKPaint { Color = color, IsAntialias = true };
        c.DrawCircle((float)x, (float)y, (float)r, p);
    }

    public static void Rect(this SKCanvas c, double x, double y, double w, double h, SKColor color)
    {
        using var p = new SKPaint { Color = color, IsAntialias = true };
        c.DrawRect(SKRect.Create((float)x, (float)y, (float)w, (float)h), p);
    }

    /// <summary>Draws an image upright into a y-up rectangle.</summary>
    public static void DrawUpright(this SKCanvas c, SKImage img, SKRect r, SKPaint? paint = null)
    {
        c.Save();
        c.Translate(r.Left, r.Bottom);
        c.Scale(1, -1);
        c.DrawImage(img, SKRect.Create(0, 0, r.Width, r.Height), paint ?? Smooth);
        c.Restore();
    }

    public static SKPath Ellipse(double cx, double cy, double rx, double ry)
    {
        var p = new SKPath();
        p.AddOval(new SKRect((float)(cx - rx), (float)(cy - ry), (float)(cx + rx), (float)(cy + ry)));
        return p;
    }

    public static SKPath CirclePath(double cx, double cy, double r) => Ellipse(cx, cy, r, r);

    public static SKPath RoundRect(double x, double y, double w, double h, double rx, double ry)
    {
        var p = new SKPath();
        p.AddRoundRect(SKRect.Create((float)x, (float)y, (float)w, (float)h), (float)rx, (float)ry);
        return p;
    }

    public static SKPath RectPath(double x, double y, double w, double h)
    {
        var p = new SKPath();
        p.AddRect(SKRect.Create((float)x, (float)y, (float)w, (float)h));
        return p;
    }

    public static SKPath Line(double x0, double y0, double x1, double y1)
    {
        var p = new SKPath();
        p.MoveTo((float)x0, (float)y0);
        p.LineTo((float)x1, (float)y1);
        return p;
    }

    public static void M(this SKPath p, double x, double y) => p.MoveTo((float)x, (float)y);
    public static void L(this SKPath p, double x, double y) => p.LineTo((float)x, (float)y);
    public static void Q(this SKPath p, double cx, double cy, double x, double y) => p.QuadTo((float)cx, (float)cy, (float)x, (float)y);
    public static void C(this SKPath p, double c1x, double c1y, double c2x, double c2y, double x, double y) =>
        p.CubicTo((float)c1x, (float)c1y, (float)c2x, (float)c2y, (float)x, (float)y);
}
