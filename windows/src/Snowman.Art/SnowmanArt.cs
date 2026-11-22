using SkiaSharp;
using Snowman.Core;
using static Snowman.Art.Col;
using static Snowman.Art.Draw;

namespace Snowman.Art;

public enum SnowmanPart { Body, Head, LeftArm, RightArm, Eyes, EyesClosed, Nose, Mouth, Cheeks, Buttons, Scarf, ScarfTail, Hat }

/// <summary>
/// One drawn piece of a snowman plus where it goes. Reference snowman: ground point (0,0),
/// body radius 30, head radius 21, y up. Anchor is normalised with origin bottom-left.
/// </summary>
public sealed record PartImage(SKImage Image, double Width, double Height, double AnchorX, double AnchorY, double PosX, double PosY, double Z);

internal enum ScarfPattern { EndStripes, Stripes, Knit, Dots }

internal sealed record StylePalette(uint Scarf, uint ScarfDark, uint Accent, ScarfPattern Pattern, uint? Mittens, uint? Buttons, double Cheeks)
{
    public static StylePalette Of(SnowmanStyle s) => s switch
    {
        SnowmanStyle.Santa => new(0x2E9E5B, 0x1D6E3E, 0xFFFFFF, ScarfPattern.EndStripes, 0x34A853, 0x1F1F24, 0.45),
        SnowmanStyle.Beanie => new(0xE23B3B, 0xA92424, 0xFFFFFF, ScarfPattern.Stripes, null, 0x3B6FD8, 0.5),
        SnowmanStyle.Gentleman => new(0xC8102E, 0x850A1E, 0x5E0715, ScarfPattern.Knit, null, 0x1F1F24, 0),
        SnowmanStyle.Earmuffs => new(0x4FCDB7, 0x2E9C88, 0xFFFFFF, ScarfPattern.Dots, 0xFF8FB1, null, 0.65),
        _ => new(0x8E5CD9, 0x6438B0, 0xF5C84C, ScarfPattern.Stripes, 0xD7263D, 0xF2C14E, 0.45),
    };
}

public static class SnowmanArt
{
    public const double BodyRadius = 30;
    public const double HeadRadius = 21;
    public static readonly (double X, double Y) BodyCenter = (0, 30);
    public static readonly (double X, double Y) HeadCenter = (0, 71);
    public const double ReferenceHeight = 92;

    private static readonly SKColor Coal = Hex(0x1F1F24);
    private static readonly SKColor MouthDark = Hex(0x3A1D1D);
    private static readonly SKColor Tongue = Hex(0xF27B8A);

    public static IReadOnlyList<SnowmanPart> Parts(SnowmanStyle style)
    {
        var pal = StylePalette.Of(style);
        return Enum.GetValues<SnowmanPart>().Where(p => p switch
        {
            SnowmanPart.Cheeks => pal.Cheeks > 0,
            SnowmanPart.Buttons => pal.Buttons is not null,
            _ => true,
        }).ToList();
    }

    public static PartImage? Part(SnowmanPart part, SnowmanStyle style, double scale)
    {
        if (!Parts(style).Contains(part)) return null;
        var pal = StylePalette.Of(style);
        switch (part)
        {
            case SnowmanPart.Body:
                return Make(64, 64, 0.5, 0.5, BodyCenter.X, BodyCenter.Y, 1, scale, c => DrawSnowBall(c, 32, 32, BodyRadius));
            case SnowmanPart.Head:
                return Make(46, 46, 0.5, 0.5, HeadCenter.X, HeadCenter.Y, 3, scale, c => DrawSnowBall(c, 23, 23, HeadRadius));
            case SnowmanPart.LeftArm:
                return Make(42, 30, 40.0 / 42, 6.0 / 30, -23, 47, 0, scale, c => DrawArm(c, pal.Mittens));
            case SnowmanPart.RightArm:
                return Make(42, 30, 2.0 / 42, 6.0 / 30, 23, 47, 0, scale, c =>
                {
                    c.Translate(42, 0);
                    c.Scale(-1, 1);
                    DrawArm(c, pal.Mittens);
                });
            case SnowmanPart.Eyes:
                return Make(28, 12, 0.5, 0.5, 0, 76, 5, scale, c => DrawEyes(c, style, false));
            case SnowmanPart.EyesClosed:
                return Make(28, 12, 0.5, 0.5, 0, 76, 5, scale, c => DrawEyes(c, style, true));
            case SnowmanPart.Nose:
                return Make(18, 8, 0.05, 0.5, -0.5, 70, 6, scale, DrawCarrot);
            case SnowmanPart.Mouth:
                return Make(26, 12, 0.5, 0.5, 0, 62, 5, scale, c => DrawMouth(c, style));
            case SnowmanPart.Cheeks:
                return Make(36, 10, 0.5, 0.5, 0, 66, 4.5, scale, c =>
                {
                    foreach (var x in new[] { 6.0, 30.0 })
                    {
                        using var outer = Ellipse(x, 5, 5, 3.4);
                        c.Fill(outer, Hex(0xFF7FA0, pal.Cheeks * 0.35));
                        using var inner = Ellipse(x, 5, 3.6, 2.3);
                        c.Fill(inner, Hex(0xFF6F96, pal.Cheeks));
                    }
                });
            case SnowmanPart.Buttons:
            {
                uint color = pal.Buttons ?? 0x1F1F24;
                bool isCoal = color == 0x1F1F24;
                double[] ys = style == SnowmanStyle.Gentleman ? new[] { 27.0, 17.0, 7.0 } : new[] { 24.0, 11.0 };
                return Make(10, 34, 0.5, 0.5, 0, 30, 2, scale, c =>
                {
                    foreach (var y in ys)
                    {
                        if (isCoal)
                        {
                            c.Circle(5, y, 2.4, Coal);
                            c.Circle(5.7, y + 0.8, 0.7, Hex(0xFFFFFF, 0.7));
                        }
                        else
                        {
                            c.Circle(5, y, 2.7, Hex(color));
                            using var ring = CirclePath(5, y, 2.7);
                            c.Stroke(ring, Mix(Hex(color), Hex(0x000000), 0.35), 0.5);
                            c.Circle(4.2, y, 0.45, Mix(Hex(color), Hex(0x000000), 0.5));
                            c.Circle(5.8, y, 0.45, Mix(Hex(color), Hex(0x000000), 0.5));
                        }
                    }
                });
            }
            case SnowmanPart.Scarf:
                return Make(56, 18, 0.5, 0.5, 0, 53, 4, scale, c => DrawScarfBand(c, pal));
            case SnowmanPart.ScarfTail:
                return Make(14, 30, 0.5, 0.96, 12, 51, 3.8, scale, c => DrawScarfTail(c, pal));
            default:
                return Hat(style, scale);
        }
    }

    /// <summary>Whole snowman drawn into one image `height` points tall (menus, help).</summary>
    public static SKImage Composite(SnowmanStyle style, double height, double scale)
    {
        var pieces = Parts(style).Where(p => p != SnowmanPart.EyesClosed).ToList();
        double minX = double.MaxValue, minY = double.MaxValue, maxX = double.MinValue, maxY = double.MinValue;
        foreach (var p in pieces)
        {
            var probe = Part(p, style, 1)!;
            var r = RectOf(probe);
            minX = Math.Min(minX, r.Left); minY = Math.Min(minY, r.Top);
            maxX = Math.Max(maxX, r.Right); maxY = Math.Max(maxY, r.Bottom);
            probe.Image.Dispose();
        }
        minX -= 2; minY -= 2; maxX += 2; maxY += 2;
        double s = height / (maxY - minY);
        var images = pieces.Select(p => Part(p, style, scale * s)!).OrderBy(p => p.Z).ToList();
        var result = Image((maxX - minX) * s, height, scale, c =>
        {
            c.Scale((float)s, (float)s);
            c.Translate((float)-minX, (float)-minY);
            foreach (var p in images) c.DrawUpright(p.Image, RectOf(p));
        });
        foreach (var p in images) p.Image.Dispose();
        return result;
    }

    /// <summary>Where a part lands in reference coordinates (y-up; Top is the low edge).</summary>
    public static SKRect RectOf(PartImage p) =>
        SKRect.Create((float)(p.PosX - p.AnchorX * p.Width), (float)(p.PosY - p.AnchorY * p.Height), (float)p.Width, (float)p.Height);

    private static PartImage Make(double w, double h, double ax, double ay, double px, double py, double z, double scale, Action<SKCanvas> draw) =>
        new(Image(w, h, scale, draw), w, h, ax, ay, px, py, z);

    public static void DrawSnowBall(SKCanvas c, double cx, double cy, double r)
    {
        using var path = CirclePath(cx, cy, r);
        c.Clipped(path, () =>
        {
            c.FillRadial(new[] { Hex(0xFFFFFF), Hex(0xF6F9FF), Hex(0xDDE7F5), Hex(0xBACBE3) }, new[] { 0f, 0.42f, 0.8f, 1f },
                         P(cx - r * 0.3, cy + r * 0.35), (float)(r * 1.6));
            c.FillLinear(new[] { Hex(0x8FA6C9, 0), Hex(0x8FA6C9, 0.28) }, null, P(cx, cy - r * 0.15), P(cx, cy - r));
            var rng = new SeededGenerator((ulong)(r * 977));
            int n = (int)(r * 0.9);
            for (int i = 0; i < n; i++)
            {
                double a = rng.Range(0, 2 * Math.PI);
                double d = Math.Sqrt(rng.Unit()) * r * 0.92;
                c.Circle(cx + Math.Cos(a) * d, cy + Math.Sin(a) * d, rng.Range(0.25, 0.6), Hex(0xB9CAE2, 0.55));
            }
            using var rim = CirclePath(cx + r * 0.04, cy - r * 0.04, r * 0.96);
            c.Stroke(rim, Hex(0xFFFFFF, 0.35), r * 0.05);
        });
        c.Stroke(path, Hex(0x9DB2D2, 0.6), Math.Max(0.6, r * 0.028));
    }

    private static void DrawArm(SKCanvas c, uint? mitten)
    {
        var brown = Hex(0x7A4E2A);
        var dark = Hex(0x4A2E17);
        using var main = new SKPath();
        main.M(40, 6);
        main.Q(24, 9, 9, 21);
        c.Stroke(main, dark, 3.4);
        c.Stroke(main, brown, 2.2);
        if (mitten is uint m)
        {
            var color = Hex(m);
            var edge = Mix(color, Hex(0x000000), 0.35);
            using var palm = Ellipse(7, 22, 5.4, 5.0);
            c.Fill(palm, color);
            c.Stroke(palm, edge, 0.7);
            using var thumb = Ellipse(10.5, 27, 2.1, 2.6);
            c.Fill(thumb, color);
            c.Stroke(thumb, edge, 0.6);
            c.Circle(5.5, 23.5, 1.4, Mix(color, Hex(0xFFFFFF), 0.45));
            using var cuff = RoundRect(10.5, 16.5, 4.2, 6, 1.5, 1.5);
            c.Fill(cuff, Hex(0xFFFFFF));
            c.Stroke(cuff, Hex(0xC9D3E3), 0.5);
        }
        else
        {
            foreach (var t in new[] { Line(15, 18, 8, 27.5), Line(12, 19.5, 1.5, 17), Line(26, 10.5, 23, 16.5) })
            {
                c.Stroke(t, dark, 2.4);
                c.Stroke(t, brown, 1.4);
                t.Dispose();
            }
        }
    }

    private static void CoalEye(SKCanvas c, double x, double y, double rx, double ry)
    {
        using var e = Ellipse(x, y, rx, ry);
        c.Fill(e, Coal);
        c.Circle(x + rx * 0.35, y + ry * 0.38, Math.Max(0.6, rx * 0.34), Hex(0xFFFFFF, 0.95));
    }

    private static void HappyArc(SKCanvas c, double x, double y)
    {
        using var p = new SKPath();
        p.M(x - 3.2, y - 1.2);
        p.Q(x, y + 3.4, x + 3.2, y - 1.2);
        c.Stroke(p, Coal, 1.8);
    }

    private static void ClosedArc(SKCanvas c, double x, double y)
    {
        using var p = new SKPath();
        p.M(x - 3, y + 0.6);
        p.Q(x, y - 2.2, x + 3, y + 0.6);
        c.Stroke(p, Coal, 1.5);
    }

    private static void DrawEyes(SKCanvas c, SnowmanStyle style, bool closed)
    {
        (double X, double Y) l = (7, 6), r = (21, 6);
        if (closed)
        {
            if (style == SnowmanStyle.Elf) { HappyArc(c, l.X, l.Y); HappyArc(c, r.X, r.Y); }
            else { ClosedArc(c, l.X, l.Y); ClosedArc(c, r.X, r.Y); }
            return;
        }
        switch (style)
        {
            case SnowmanStyle.Santa:
                CoalEye(c, l.X, l.Y, 2.6, 3.0); CoalEye(c, r.X, r.Y, 2.6, 3.0); break;
            case SnowmanStyle.Beanie:
                CoalEye(c, l.X, l.Y, 2.6, 3.0); HappyArc(c, r.X, r.Y); break;
            case SnowmanStyle.Gentleman:
                CoalEye(c, l.X, l.Y, 2.3, 2.6); CoalEye(c, r.X, r.Y, 2.3, 2.6); break;
            case SnowmanStyle.Earmuffs:
                CoalEye(c, l.X, l.Y, 3.3, 3.6); CoalEye(c, r.X, r.Y, 3.3, 3.6);
                c.Circle(l.X - 1.1, l.Y - 1.2, 0.5, Hex(0xFFFFFF, 0.8));
                c.Circle(r.X - 1.1, r.Y - 1.2, 0.5, Hex(0xFFFFFF, 0.8));
                break;
            default:
                HappyArc(c, l.X, l.Y); HappyArc(c, r.X, r.Y); break;
        }
    }

    private static void DrawCarrot(SKCanvas c)
    {
        using var p = new SKPath();
        p.M(1, 1.0);
        p.Q(9, 1.4, 17.2, 3.7);
        p.Q(9, 6.6, 1, 7.0);
        p.Close();
        c.Clipped(p, () =>
        {
            c.FillLinear(new[] { Hex(0xFFA24A), Hex(0xF26B12), Hex(0xD9530A) }, new[] { 0f, 0.55f, 1f }, P(0, 7), P(0, 1));
            foreach (var x in new[] { 5.5, 9.5, 13.0 })
            {
                using var l = Line(x, 2, x + 0.8, 4.2);
                c.Stroke(l, Hex(0xB8460A, 0.75), 0.55);
            }
        });
        c.Stroke(p, Hex(0xB8460A, 0.55), 0.5);
    }

    private static void DrawMouth(SKCanvas c, SnowmanStyle style)
    {
        switch (style)
        {
            case SnowmanStyle.Santa:
            {
                using var p = new SKPath();
                p.M(6, 8.5);
                p.Q(13, 9.6, 20, 8.5);
                p.Q(13, -1.5, 6, 8.5);
                p.Close();
                c.Fill(p, MouthDark);
                c.Clipped(p, () => { using var t = Ellipse(13, 3.6, 3.8, 2.4); c.Fill(t, Tongue); });
                break;
            }
            case SnowmanStyle.Beanie:
            {
                using var p = new SKPath();
                p.M(6, 7.5);
                p.Q(12.5, 1.5, 19.5, 8);
                c.Stroke(p, MouthDark, 1.7);
                using var t = Ellipse(15.6, 4.3, 1.9, 1.6);
                c.Fill(t, Tongue);
                c.Stroke(t, Hex(0xC9566A), 0.4);
                break;
            }
            case SnowmanStyle.Gentleman:
                for (int i = 0; i < 5; i++)
                {
                    double t = i / 4.0;
                    c.Circle(6 + 14 * t, 8 - Math.Sin(t * Math.PI) * 4, 1.25, Coal);
                }
                break;
            case SnowmanStyle.Earmuffs:
            {
                using var o = Ellipse(13, 5.5, 2.7, 3.4);
                c.Fill(o, MouthDark);
                using var t = Ellipse(13, 3.7, 1.7, 1.2);
                c.Fill(t, Tongue);
                break;
            }
            default:
            {
                using var p = new SKPath();
                p.M(8, 7.2);
                p.Q(13, 2.6, 18, 7.2);
                c.Stroke(p, MouthDark, 1.6);
                break;
            }
        }
    }

    private static void ScarfPatternFill(SKCanvas c, StylePalette pal, SKRect b, bool horizontal)
    {
        var accent = Hex(pal.Accent);
        switch (pal.Pattern)
        {
            case ScarfPattern.Stripes:
                if (horizontal) for (float y = b.Top + 3; y < b.Bottom; y += 7) c.Rect(b.Left, y, b.Width, 3, accent);
                else for (float x = b.Left + 4; x < b.Right; x += 7) c.Rect(x, b.Top, 3, b.Height, accent);
                break;
            case ScarfPattern.EndStripes:
                if (horizontal) foreach (var y in new[] { b.Top + 6, b.Top + 10 }) c.Rect(b.Left, y, b.Width, 1.8, accent);
                else foreach (var x in new[] { b.Left + 6, b.Left + 10, b.Right - 12, b.Right - 8 }) c.Rect(x, b.Top, 1.8, b.Height, accent);
                break;
            case ScarfPattern.Knit:
                for (float x = b.Left - b.Height; x < b.Right; x += 3)
                {
                    using var l = Line(x, b.Top, x + b.Height * 0.6, b.Bottom);
                    c.Stroke(l, Hex(pal.Accent, 0.45), 0.7);
                }
                break;
            default:
            {
                int row = 0;
                for (float y = b.Top + 2.5f; y < b.Bottom; y += 4.5f)
                {
                    for (float x = b.Left + 2.5f + (row % 2) * 2.5f; x < b.Right; x += 5) c.Circle(x, y, 1.05, accent);
                    row++;
                }
                break;
            }
        }
    }

    private static void DrawScarfBand(SKCanvas c, StylePalette pal)
    {
        using var band = new SKPath();
        band.M(4, 12.5);
        band.Q(28, 9, 52, 12.5);
        band.L(53, 4.5);
        band.Q(28, -0.5, 3, 4.5);
        band.Close();
        c.Clipped(band, () =>
        {
            c.Rect(0, 0, 56, 18, Hex(pal.Scarf));
            ScarfPatternFill(c, pal, SKRect.Create(0, 0, 56, 18), false);
            c.FillLinear(new[] { Hex(0x000000, 0.22), Hex(0x000000, 0), Hex(0xFFFFFF, 0.18) }, new[] { 0f, 0.55f, 1f }, P(0, 1), P(0, 13));
        });
        c.Stroke(band, Hex(pal.ScarfDark, 0.65), 0.8);
        using var knot = Ellipse(40, 7.5, 5.2, 5.4);
        c.Fill(knot, Hex(pal.Scarf));
        c.Clipped(knot, () =>
        {
            ScarfPatternFill(c, pal, SKRect.Create(34, 2, 12, 12), true);
            c.FillRadial(new[] { Hex(0xFFFFFF, 0.25), Hex(0x000000, 0.2) }, null, P(40, 7.5), 6, P(38.5, 9.5));
        });
        c.Stroke(knot, Hex(pal.ScarfDark, 0.7), 0.8);
    }

    private static void DrawScarfTail(SKCanvas c, StylePalette pal)
    {
        using var tail = new SKPath();
        tail.M(2.5, 29);
        tail.L(11.5, 29);
        tail.Q(13.5, 17, 12.5, 6);
        tail.L(2, 5);
        tail.Q(0.5, 17, 2.5, 29);
        tail.Close();
        c.Clipped(tail, () =>
        {
            c.Rect(0, 0, 14, 30, Hex(pal.Scarf));
            ScarfPatternFill(c, pal, SKRect.Create(0, 4, 14, 26), true);
            c.FillLinear(new[] { Hex(0x000000, 0.18), Hex(0x000000, 0) }, null, P(12, 0), P(4, 0));
        });
        c.Stroke(tail, Hex(pal.ScarfDark, 0.65), 0.8);
        for (int i = 0; i < 5; i++)
        {
            double x = 3 + i * 2.2;
            using var f = Line(x, 5.5, x - 0.3, 1);
            c.Stroke(f, Hex(pal.ScarfDark), 1.0);
        }
    }

    private static PartImage Hat(SnowmanStyle style, double scale) => style switch
    {
        SnowmanStyle.Santa => Make(70, 54, 30.0 / 70, 0, 0, 84, 7, scale, c =>
        {
            using var cone = new SKPath();
            cone.M(12, 8);
            cone.C(13, 30, 24, 45, 38, 45);
            cone.C(50, 45, 57, 36, 58, 26);
            cone.C(54, 22, 49, 18, 48, 8);
            cone.Close();
            c.Clipped(cone, () =>
            {
                c.FillLinear(new[] { Hex(0xF04452), Hex(0xD62839), Hex(0xA9182A) }, new[] { 0f, 0.5f, 1f }, P(12, 40), P(56, 12));
                using var fold = new SKPath();
                fold.M(36, 42);
                fold.Q(46, 28, 44, 9);
                c.Stroke(fold, Hex(0x8E1222, 0.45), 2.2);
            });
            c.Stroke(cone, Hex(0x8E1222, 0.6), 0.8);
            FluffyBand(c, 8, 1, 44, 10.5);
            FluffyBall(c, 59, 23, 6.8);
        }),
        SnowmanStyle.Beanie => Make(48, 40, 0.5, 0, 0, 84, 7, scale, c =>
        {
            using var dome = new SKPath();
            dome.M(5, 6);
            dome.C(5, 35, 43, 35, 43, 6);
            dome.Close();
            c.Clipped(dome, () =>
            {
                c.FillLinear(new[] { Hex(0x5C8BEA), Hex(0x3B6FD8), Hex(0x2A52AE) }, new[] { 0f, 0.5f, 1f }, P(8, 30), P(42, 6));
                for (int row = 0; row < 5; row++)
                {
                    double y = 10 + row * 4.5;
                    for (int col = 0; col < 10; col++)
                    {
                        double x = 4 + col * 4.4 + (row % 2) * 2.2;
                        using var v = new SKPath();
                        v.M(x - 1.4, y + 1.6); v.L(x, y); v.L(x + 1.4, y + 1.6);
                        c.Stroke(v, Hex(0xFFFFFF, 0.22), 0.7);
                    }
                }
            });
            c.Stroke(dome, Hex(0x1F3F8A, 0.6), 0.8);
            using var band = RoundRect(3, 0, 42, 9.5, 4, 4);
            c.Clipped(band, () =>
            {
                c.Rect(0, 0, 48, 10, Hex(0x2F5FC4));
                for (double x = 4.5; x < 45; x += 3) c.Rect(x, 0, 1.2, 10, Hex(0x6E97EC, 0.8));
                c.FillLinear(new[] { Hex(0x000000, 0.18), Hex(0x000000, 0) }, null, P(0, 0), P(0, 9));
            });
            c.Stroke(band, Hex(0x1F3F8A, 0.6), 0.8);
            FluffyBall(c, 24, 32, 6.2);
        }),
        SnowmanStyle.Gentleman => Make(50, 40, 0.5, 0, 0, 85, 7, scale, c =>
        {
            using var crown = new SKPath();
            crown.M(12.5, 3); crown.L(11, 34); crown.L(39, 34); crown.L(37.5, 3); crown.Close();
            c.Clipped(crown, () =>
            {
                c.FillLinear(new[] { Hex(0x3A3A44), Hex(0x23232A), Hex(0x111115) }, new[] { 0f, 0.35f, 1f }, P(11, 0), P(39, 0));
                c.Rect(10, 5, 30, 6.5, Hex(0xC8102E));
                c.Rect(10, 10.6, 30, 0.9, Hex(0xFFFFFF, 0.18));
                c.Rect(14, 12, 2.2, 21, Hex(0xFFFFFF, 0.12));
            });
            using var top = Ellipse(25, 34, 14, 2.4);
            c.Fill(top, Hex(0x2C2C34));
            c.Stroke(top, Hex(0x0B0B0E), 0.6);
            using var brim = Ellipse(25, 3.4, 23, 3.4);
            c.Fill(brim, Hex(0x18181D));
            c.Stroke(brim, Hex(0x48484F), 0.6);
            foreach (var (angle, dx) in new[] { (0.55, -3.2), (-0.55, 3.2) })
            {
                c.Save();
                c.Translate((float)(17 + dx), 9.5f);
                c.RotateRadians((float)angle);
                using var leaf = Ellipse(0, 0, 4.2, 1.9);
                c.Fill(leaf, Hex(0x2E8B3E));
                using var vein = Line(-3.5, 0, 3.5, 0);
                c.Stroke(vein, Hex(0x1B5E27), 0.4);
                c.Restore();
            }
            foreach (var (x, y) in new[] { (16.0, 10.5), (18.3, 11.6), (18.6, 9.2) })
            {
                c.Circle(x, y, 1.55, Hex(0xE0242E));
                c.Circle(x - 0.4, y + 0.4, 0.45, Hex(0xFFFFFF, 0.7));
            }
        }),
        SnowmanStyle.Earmuffs => Make(62, 40, 0.5, 0, 0, 62, 7, scale, c =>
        {
            using var band = new SKPath();
            band.M(12, 14);
            band.Q(31, 52, 50, 14);
            c.Stroke(band, Hex(0xC9567A), 4.2);
            c.Stroke(band, Hex(0xF27AA0), 2.6);
            FluffyMuff(c, 11, 10.5, 8.5);
            FluffyMuff(c, 51, 10.5, 8.5);
        }),
        _ => Make(84, 60, 22.0 / 84, 0, 0, 84, 7, scale, c =>
        {
            using var cone = new SKPath();
            cone.M(5, 8);
            cone.C(8, 34, 20, 50, 34, 50);
            cone.C(48, 51, 60, 48, 68, 40);
            cone.C(58, 36, 44, 28, 39, 8);
            cone.Close();
            c.Clipped(cone, () =>
            {
                c.FillLinear(new[] { Hex(0x4CC764), Hex(0x2F9E44), Hex(0x1E7A33) }, new[] { 0f, 0.5f, 1f }, P(8, 44), P(52, 10));
                using var fold = new SKPath();
                fold.M(32, 47);
                fold.Q(40, 28, 34, 9);
                c.Stroke(fold, Hex(0x145C25, 0.4), 2);
            });
            c.Stroke(cone, Hex(0x145C25, 0.65), 0.8);
            using var cuff = new SKPath();
            cuff.M(2, 11);
            cuff.L(42, 11);
            double x = 42;
            bool down = true;
            while (x > 2)
            {
                x -= 4;
                cuff.L(Math.Max(2, x), down ? 1 : 5);
                down = !down;
            }
            cuff.Close();
            c.Fill(cuff, Hex(0xD7263D));
            c.Stroke(cuff, Hex(0x8E1222, 0.6), 0.7);
            double bx = 70, by = 37.5;
            using var bell = CirclePath(bx, by, 5);
            c.Fill(bell, Hex(0xF2C14E));
            c.Clipped(bell, () =>
                c.FillRadial(new[] { Hex(0xFFF1B8), Hex(0xF2C14E), Hex(0xC9921E) }, new[] { 0f, 0.5f, 1f }, P(bx, by), 6, P(bx - 1.6, by + 1.8)));
            c.Stroke(bell, Hex(0x9C6E12), 0.6);
            using var slit = Line(bx - 2.6, by - 1.6, bx + 2.6, by - 1.6);
            c.Stroke(slit, Hex(0x6B4A0B), 1);
            c.Circle(bx, by - 3, 0.9, Hex(0x6B4A0B));
        }),
    };

    private static void FluffyBand(SKCanvas c, double x, double y, double w, double h)
    {
        using var path = RoundRect(x, y, w, h, h / 2, h / 2);
        double span = w - h;
        int count = Math.Max(1, (int)(span / 3.6));
        for (int i = 0; i <= count; i++)
        {
            double px = x + h / 2 + i * span / count;
            c.Circle(px, y + h - 1.3, 2.0, Hex(0xFFFFFF));
            if (i < count) c.Circle(px + span / count / 2, y + 1.5, 1.7, Hex(0xF4F7FC));
        }
        c.Fill(path, Hex(0xFFFFFF));
        c.Clipped(path, () =>
            c.FillLinear(new[] { Hex(0xC9D6EA, 0.75), Hex(0xFFFFFF, 0) }, null, P(0, y), P(0, y + h / 2 + 2)));
    }

    private static void FluffyBall(SKCanvas c, double cx, double cy, double r)
    {
        for (int i = 0; i < 10; i++)
        {
            double a = i / 10.0 * 2 * Math.PI;
            c.Circle(cx + Math.Cos(a) * r * 0.78, cy + Math.Sin(a) * r * 0.78, r * 0.36, Hex(0xF1F5FB));
        }
        using var core = CirclePath(cx, cy, r * 0.86);
        c.Fill(core, Hex(0xFFFFFF));
        using var shade = CirclePath(cx, cy, r * 0.95);
        c.Clipped(shade, () =>
            c.FillRadial(new[] { Hex(0xFFFFFF, 0), Hex(0xBFCDE2, 0.55) }, new[] { 0.55f, 1f }, P(cx, cy), (float)r, P(cx - r * 0.3, cy + r * 0.3)));
    }

    private static void FluffyMuff(SKCanvas c, double cx, double cy, double r)
    {
        for (int i = 0; i < 12; i++)
        {
            double a = i / 12.0 * 2 * Math.PI;
            c.Circle(cx + Math.Cos(a) * r * 0.8, cy + Math.Sin(a) * r * 0.8, r * 0.32, Hex(0xF77FA6));
        }
        using var core = CirclePath(cx, cy, r * 0.86);
        c.Fill(core, Hex(0xFF93B6));
        using var clip = CirclePath(cx, cy, r * 0.9);
        c.Clipped(clip, () =>
            c.FillRadial(new[] { Hex(0xFFD0DF), Hex(0xFF93B6, 0) }, null, P(cx - r * 0.3, cy + r * 0.3), (float)(r * 0.7)));
        for (int i = 0; i < 7; i++)
        {
            double a = i * 0.9;
            c.Circle(cx + Math.Cos(a) * r * 0.45, cy + Math.Sin(a) * r * 0.45, 0.7, Hex(0xFFFFFF, 0.45));
        }
    }
}
