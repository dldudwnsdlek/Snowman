using SkiaSharp;
using Snowman.Core;
using static Snowman.Art.Col;
using static Snowman.Art.Draw;

namespace Snowman.Art;

/// <summary>Small sprites used by the overlay.</summary>
public static class SpriteArt
{
    /// <summary>Soft round snowflake.</summary>
    public static SKImage Flake(double d, double scale, double alpha = 1) => Image(d, d, scale, c =>
        c.FillRadial(new[] { Hex(0xFFFFFF, alpha), Hex(0xFFFFFF, 0.9 * alpha), Hex(0xF0F6FF, 0.35 * alpha), Hex(0xFFFFFF, 0) },
                     new[] { 0f, 0.35f, 0.7f, 1f }, P(d / 2, d / 2), (float)(d / 2), extend: false));

    /// <summary>A lump of fallen snow.</summary>
    public static SKImage Clump(double d, double scale) => Image(d, d, scale, c =>
    {
        foreach (var (x, y, r) in new[] { (0.42, 0.45, 0.30), (0.62, 0.52, 0.26), (0.5, 0.66, 0.22), (0.34, 0.6, 0.18) })
        {
            double cx = x * d, cy = y * d, rr = r * d;
            using var blob = CirclePath(cx, cy, rr);
            c.Fill(blob, Hex(0xFFFFFF));
            c.Clipped(blob, () => c.FillRadial(new[] { Hex(0xFFFFFF, 0), Hex(0xB8C9E3, 0.7) }, new[] { 0.4f, 1f },
                                                P(cx, cy), (float)rr, P(cx - rr * 0.35, cy + rr * 0.35)));
        }
    });

    /// <summary>Green knitted mitten shown next to the cursor over snow.</summary>
    public static SKImage Mitten(double s, double scale) => Image(s, s, scale, c =>
    {
        c.Scale((float)(s / 28), (float)(s / 28));
        c.Translate(14, 14);
        c.RotateRadians(-0.35f);
        c.Translate(-14, -14);
        var green = Hex(0x2FB36A);
        var edge = Hex(0x1C7444);
        c.Save();
        c.Translate(7.4f, 13.5f);
        c.RotateRadians(0.55f);
        using (var thumb = Ellipse(0, 0, 3.4, 5.6))
        {
            c.Fill(thumb, green);
            c.Stroke(thumb, edge, 0.9);
        }
        c.Restore();
        using var palm = RoundRect(8.5, 7, 12.5, 18.5, 6.2, 6.2);
        c.Fill(palm, green);
        c.Clipped(palm, () =>
        {
            for (int row = 0; row < 5; row++)
            {
                double y = 10 + row * 3.2;
                for (int col = 0; col < 3; col++)
                {
                    double x = 11 + col * 3.4;
                    using var v = new SKPath();
                    v.M(x - 1.1, y + 1.2); v.L(x, y); v.L(x + 1.1, y + 1.2);
                    c.Stroke(v, Hex(0xFFFFFF, 0.25), 0.6);
                }
            }
            c.FillRadial(new[] { Hex(0xFFFFFF, 0.3), Hex(0xFFFFFF, 0) }, null, P(12, 21), 7);
        });
        c.Stroke(palm, edge, 0.9);
        using var cuff = RoundRect(7.8, 2.5, 14, 6, 2, 2);
        c.Fill(cuff, Hex(0xF7F9FC));
        c.Clipped(cuff, () => { for (double x = 9; x < 22; x += 2) c.Rect(x, 2.5, 0.7, 6, Hex(0xC9D3E3)); });
        c.Stroke(cuff, Hex(0x9AA7BC), 0.7);
    });

    /// <summary>Shaded snowball (drawn big, scaled down when shown).</summary>
    public static SKImage Snowball(double r, double scale) =>
        Image(2 * r + 4, 2 * r + 4, scale, c => SnowmanArt.DrawSnowBall(c, r + 2, r + 2, r));

    public const double PlowWidth = 124, PlowHeight = 66;
    public static readonly (double X, double Y)[] PlowWheelCenters = { (24, 11), (78, 11) };
    public static readonly (double X, double Y) PlowBeaconPosition = (78, 56);
    /// <summary>Front of the blade, in plow image points.</summary>
    public const double PlowBladeFront = 122;

    /// <summary>Orange snowplow truck facing right, without wheels and beacon.</summary>
    public static SKImage Plow(double scale) => Image(PlowWidth, PlowHeight, scale, c =>
    {
        var orangeTop = Hex(0xFFA23A);
        var orange = Hex(0xF28C28);
        var orangeDark = Hex(0xC96513);
        var outline = Hex(0x7A3E0E, 0.55);
        c.Rect(8, 9, 92, 7, Hex(0x3A3F4A));
        using var dump = RoundRect(4, 14, 58, 28, 5, 5);
        c.Clipped(dump, () =>
        {
            c.FillLinear(new[] { orangeTop, orange, orangeDark }, new[] { 0f, 0.55f, 1f }, P(0, 42), P(0, 14));
            c.Rect(4, 22, 58, 3.2, Hex(0xFFFFFF, 0.9));
            c.Rect(4, 25.2, 58, 1.6, Hex(0xD62839));
            for (double x = 14; x < 60; x += 12) c.Rect(x, 27, 1.2, 15, Hex(0x000000, 0.12));
        });
        c.Stroke(dump, outline, 0.9);
        using var heap = new SKPath();
        heap.M(5, 40);
        heap.C(7, 50, 16, 54, 26, 52);
        heap.C(33, 56, 40, 55, 46, 50);
        heap.C(54, 52, 61, 47, 61, 40);
        heap.Close();
        c.Fill(heap, Hex(0xFFFFFF));
        c.Clipped(heap, () => c.FillLinear(new[] { Hex(0xFFFFFF, 0), Hex(0xB8C9E3, 0.75) }, null, P(0, 52), P(0, 40)));
        c.Stroke(heap, Hex(0xA9BCD8, 0.8), 0.7);
        using var cab = new SKPath();
        cab.M(60, 14); cab.L(60, 52); cab.Q(60, 57, 66, 57); cab.L(86, 57); cab.Q(95, 56, 97, 40); cab.L(98, 14); cab.Close();
        c.Clipped(cab, () =>
        {
            c.FillLinear(new[] { orangeTop, orange, orangeDark }, new[] { 0f, 0.5f, 1f }, P(0, 57), P(0, 14));
            c.Rect(60, 22, 40, 3.2, Hex(0xFFFFFF, 0.9));
            c.Rect(60, 25.2, 40, 1.6, Hex(0xD62839));
        });
        c.Stroke(cab, outline, 0.9);
        using var window = new SKPath();
        window.M(67, 35); window.L(67, 51); window.Q(67, 53, 69, 53); window.L(84, 53); window.Q(91, 52, 92, 38); window.L(92, 35); window.Close();
        c.Clipped(window, () =>
        {
            c.FillLinear(new[] { Hex(0xCDEFFF), Hex(0x7CC6EE), Hex(0x4A9BD6) }, new[] { 0f, 0.5f, 1f }, P(0, 53), P(0, 35));
            using var glare = Line(72, 35, 80, 53);
            c.Stroke(glare, Hex(0xFFFFFF, 0.55), 3);
        });
        c.Stroke(window, Hex(0x2C5E8A, 0.7), 0.9);
        using var door = RoundRect(66, 16, 24, 17, 2, 2);
        c.Stroke(door, Hex(0x7A3E0E, 0.35), 0.7);
        c.Rect(84, 29, 4, 1.4, Hex(0x5A2E0A, 0.7));
        c.Circle(95.5, 30, 2.3, Hex(0xFFF3B0));
        c.FillRadial(new[] { Hex(0xFFF3B0, 0.7), Hex(0xFFF3B0, 0) }, null, P(96, 30), 6, extend: false);
        c.Rect(94, 13, 7, 6, Hex(0x2E323B));
        c.Rect(98, 17, 8, 4, Hex(0x2E323B));
        using var blade = new SKPath();
        blade.M(103, 3); blade.L(122, 5); blade.Q(114, 22, 120, 41); blade.L(104, 37); blade.Q(109, 20, 103, 3); blade.Close();
        c.Clipped(blade, () =>
        {
            c.FillLinear(new[] { Hex(0xFFFFFF), Hex(0xE3E8F0) }, null, P(104, 0), P(122, 0));
            for (double k = -30; k < 40; k += 9)
            {
                using var stripe = Line(100, k, 124, k + 22);
                c.Stroke(stripe, Hex(0xE63946), 3.6, SKStrokeCap.Butt);
            }
            c.FillLinear(new[] { Hex(0x000000, 0.18), Hex(0x000000, 0) }, null, P(104, 0), P(112, 0));
        });
        c.Stroke(blade, Hex(0x6B7280), 0.9);
        c.Rect(103, 2, 19.5, 2.4, Hex(0x4B5563));
    });

    public static SKImage PlowWheel(double scale) => Image(24, 24, scale, c =>
    {
        const double cx = 12, cy = 12;
        c.Circle(cx, cy, 11, Hex(0x1F2228));
        for (int i = 0; i < 12; i++)
        {
            double a = i / 12.0 * 2 * Math.PI;
            c.Circle(cx + Math.Cos(a) * 10.4, cy + Math.Sin(a) * 10.4, 1.3, Hex(0x2C3038));
        }
        c.Circle(cx, cy, 5.6, Hex(0xB9C0CB));
        using var hub = CirclePath(cx, cy, 5.6);
        c.Stroke(hub, Hex(0x6B7280), 0.7);
        for (int i = 0; i < 5; i++)
        {
            double a = i / 5.0 * 2 * Math.PI;
            c.Circle(cx + Math.Cos(a) * 3.4, cy + Math.Sin(a) * 3.4, 0.8, Hex(0x4B5563));
        }
        c.Circle(cx, cy, 1.6, Hex(0x4B5563));
        c.Circle(cx - 1.8, cy + 2.2, 1.2, Hex(0xFFFFFF, 0.5));
    });

    public static SKImage PlowBeacon(double scale) => Image(12, 10, scale, c =>
    {
        c.Rect(1, 0, 10, 2.2, Hex(0x3A3F4A));
        using var dome = new SKPath();
        dome.M(2, 2);
        dome.C(2, 10.5, 10, 10.5, 10, 2);
        dome.Close();
        c.Clipped(dome, () => c.FillLinear(new[] { Hex(0xFFE066), Hex(0xFFB703), Hex(0xFB8500) }, new[] { 0f, 0.5f, 1f }, P(0, 9), P(0, 2)));
        c.Circle(4.6, 5.6, 1.1, Hex(0xFFFFFF, 0.8));
    });

    /// <summary>Soft radial glow (beacon light).</summary>
    public static SKImage Glow(double r, uint color, double scale) => Image(2 * r, 2 * r, scale, c =>
        c.FillRadial(new[] { Hex(color, 0.85), Hex(color, 0.3), Hex(color, 0) }, new[] { 0f, 0.4f, 1f }, P(r, r), (float)r, extend: false));

    /// <summary>Burst of snow dust for impacts.</summary>
    public static SKImage Puff(double scale) => Image(40, 40, scale, c =>
    {
        var rng = new SeededGenerator(42);
        for (int i = 0; i < 9; i++)
        {
            double a = rng.Range(0, 2 * Math.PI);
            double d = rng.Range(2, 10);
            double r = rng.Range(6, 10);
            c.FillRadial(new[] { Hex(0xFFFFFF, 0.95), Hex(0xF2F6FD, 0.6), Hex(0xFFFFFF, 0) }, new[] { 0f, 0.55f, 1f },
                         P(20 + Math.Cos(a) * d, 20 + Math.Sin(a) * d), (float)r, extend: false);
        }
    });

    /// <summary>Four-point sparkle for the snowman build moment.</summary>
    public static SKImage Sparkle(double scale) => Image(18, 18, scale, c =>
    {
        c.FillRadial(new[] { Hex(0xFFF6C2, 0.75), Hex(0xFFF6C2, 0) }, null, P(9, 9), 9, extend: false);
        using var star = new SKPath();
        star.M(9, 17.5);
        star.Q(10.2, 10.2, 17.5, 9);
        star.Q(10.2, 7.8, 9, 0.5);
        star.Q(7.8, 7.8, 0.5, 9);
        star.Q(7.8, 10.2, 9, 17.5);
        star.Close();
        c.Fill(star, Hex(0xFFFFFF));
    });

    /// <summary>Snowflake glyph for the notification-area icon (readable on light and dark taskbars).</summary>
    public static SKImage TraySnowflake(int pixels) => Image(32, 32, pixels / 32.0, c =>
    {
        using var arms = new SKPath();
        for (int i = 0; i < 6; i++)
        {
            double a = i * Math.PI / 3 + Math.PI / 2;
            double ca = Math.Cos(a), sa = Math.Sin(a);
            arms.M(16, 16);
            arms.L(16 + ca * 13, 16 + sa * 13);
            foreach (var t in new[] { 7.0, 10.5 })
            {
                double bx = 16 + ca * t, by = 16 + sa * t;
                foreach (var side in new[] { 0.7, -0.7 })
                {
                    arms.M(bx, by);
                    arms.L(bx + Math.Cos(a + side) * 3.6, by + Math.Sin(a + side) * 3.6);
                }
            }
        }
        c.Stroke(arms, Hex(0x1B3A6B, 0.85), 4.6);
        c.Stroke(arms, Hex(0xEAF4FF), 2.4);
        c.Circle(16, 16, 2.6, Hex(0xEAF4FF));
    });
}
