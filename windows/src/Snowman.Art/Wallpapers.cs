using SkiaSharp;
using Snowman.Core;
using static Snowman.Art.Col;
using static Snowman.Art.Draw;

namespace Snowman.Art;

/// <summary>The ten winter wallpapers, drawn entirely in code.</summary>
public enum WinterWallpaper
{
    AuroraNight, MoonlitCabin, GoldenForest, FrozenLake, SnowyVillage,
    ChristmasTree, BlueDawnPeaks, BirchForest, MilkyWay, PinkSunset,
}

public static class WallpaperArt
{
    public static readonly WinterWallpaper[] All = Enum.GetValues<WinterWallpaper>();

    public static string Title(this WinterWallpaper w) => w switch
    {
        WinterWallpaper.AuroraNight => "오로라의 밤",
        WinterWallpaper.MoonlitCabin => "달빛 오두막",
        WinterWallpaper.GoldenForest => "황금빛 설원 숲",
        WinterWallpaper.FrozenLake => "얼어붙은 호수",
        WinterWallpaper.SnowyVillage => "눈 내리는 마을",
        WinterWallpaper.ChristmasTree => "크리스마스 트리",
        WinterWallpaper.BlueDawnPeaks => "푸른 새벽 설산",
        WinterWallpaper.BirchForest => "자작나무 숲",
        WinterWallpaper.MilkyWay => "은하수 설원",
        _ => "분홍 노을 언덕",
    };

    public static string FileStem(this WinterWallpaper w) => $"winter-{(int)w + 1:00}";

    /// <summary>Renders the wallpaper at an exact pixel size. Same input → same pixels.</summary>
    public static SKImage Render(this WinterWallpaper w, int width, int height)
    {
        using var surface = NewSurface(width, height);
        var k = new LandscapeKit(surface, width, height);
        var rng = new SeededGenerator(unchecked((ulong)((int)w + 1) * 7919UL));
        switch (w)
        {
            case WinterWallpaper.AuroraNight: Scenes.Aurora(k, rng); break;
            case WinterWallpaper.MoonlitCabin: Scenes.Cabin(k, rng); break;
            case WinterWallpaper.GoldenForest: Scenes.Golden(k, rng); break;
            case WinterWallpaper.FrozenLake: Scenes.Lake(k, rng); break;
            case WinterWallpaper.SnowyVillage: Scenes.Village(k, rng); break;
            case WinterWallpaper.ChristmasTree: Scenes.Christmas(k, rng); break;
            case WinterWallpaper.BlueDawnPeaks: Scenes.Dawn(k, rng); break;
            case WinterWallpaper.BirchForest: Scenes.Birches(k, rng); break;
            case WinterWallpaper.MilkyWay: Scenes.MilkyWay(k, rng); break;
            default: Scenes.Pink(k, rng); break;
        }
        k.Grain();
        k.C.Flush();
        return surface.Snapshot();
    }
}

internal static class Scenes
{
    private static int StarCount(LandscapeKit k, double density) => (int)(k.W / k.U * density);

    // 1 오로라의 밤
    public static void Aurora(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0x1C3D70), (0.35, 0x0F2650), (0.7, 0x071633), (1, 0x030A1D));
        k.Stars(rng, StarCount(k, 0.45), 0.3, 1.2);
        k.BlurLayer(0.25, k.Px(12), c =>
        {
            var curtains = new (double BaseY, double Amp, double Height, uint Color, double Phase)[]
            {
                (560, 70, 260, 0x3DF2A0, 0.3), (630, 60, 220, 0x29D3C8, 2.1), (700, 50, 200, 0x9B6CF2, 4.0),
            };
            foreach (var cu in curtains)
            {
                const int steps = 220;
                using var line = new SKPath();
                for (int i = 0; i < steps; i++)
                {
                    double fx = (double)i / steps;
                    double x = fx * k.W;
                    double yb = k.Px(cu.BaseY + cu.Amp * Math.Sin(fx * 2 * Math.PI * 1.3 + cu.Phase) + cu.Amp * 0.4 * Math.Sin(fx * 2 * Math.PI * 3.1 + cu.Phase * 1.7));
                    double swell = 0.35 + 0.65 * Math.Pow(0.5 + 0.5 * Math.Sin(fx * 2 * Math.PI * 2.2 + cu.Phase * 0.6), 2);
                    double hgt = k.Px(cu.Height * swell * rng.Range(0.8, 1.2));
                    c.Clipped(SKRect.Create((float)x, (float)yb, (float)(k.W / steps + 1), (float)hgt), () =>
                        c.FillLinear(new[] { Hex(cu.Color, 0.95), Hex(cu.Color, 0.45), Hex(cu.Color, 0) }, new[] { 0f, 0.22f, 1f }, P(0, yb), P(0, yb + hgt)));
                    if (i == 0) line.M(x, yb); else line.L(x, yb);
                }
                c.Stroke(line, Hex(cu.Color, 0.9), k.Px(3));
            }
        }, SKBlendMode.Screen);
        var far = k.RidgePoints(rng, 250, 55, 0.55, (0.18, 130, 0.12), (0.6, 170, 0.15), (0.86, 100, 0.1));
        k.Mountains(far, 0x2E4A80, 0x1C3159, 0xA9BEE6, 300, rng, shadeAlpha: 0.32);
        var near = k.RidgePoints(rng, 175, 40, 0.55, (0.35, 70, 0.14), (0.75, 60, 0.12));
        k.Mountains(near, 0x18294F, 0x0F1C38, 0x7F97C8, 225, rng);
        k.Forest(rng, 80, (0, 1), (125, 165), (50, 120), 0x08142B, 0x6F86B5, 0.6);
        var field = new (double, double, double)[] { (14, 0.7, 0.4), (8, 2.3, 1.7) };
        k.Hills(115, field, 0xC9D8F2, 0x8EA5CF, 0xEAF2FF);
        k.Glow(k.Fx(0.45), k.Px(90), k.Px(650), 0x3DF2A0, 0.16);
        k.Sparkles(rng, StarCount(k, 0.25), 120);
        k.Pine(k.Fx(0.05), k.Px(40), k.Px(420), Hex(0x061026), Hex(0x9FB4DC));
        k.Pine(k.Fx(0.95), k.Px(30), k.Px(360), Hex(0x061026), Hex(0x9FB4DC));
    }

    // 2 달빛 오두막
    public static void Cabin(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0x3E5A94), (0.4, 0x1E3466), (1, 0x0A1633));
        k.Stars(rng, StarCount(k, 0.25), 0.45);
        k.Moon(k.Fx(0.8), k.Px(810), k.Px(52));
        var far = new (double, double, double)[] { (22, 1.2, 0.3), (10, 3.1, 1.1) };
        k.Hills(330, far, 0x3E5A92, 0x2C4677, 0x8FA8D6);
        k.Forest(rng, 110, (0, 1), (0, 0), (35, 85), 0x1A2C55, 0x8DA3CF, 0.85, x => k.HillY(330, far, x) - k.Px(4));
        var mid = new (double, double, double)[] { (18, 0.6, 2.0), (6, 2.7, 0.2) };
        k.Hills(235, mid, 0xDCE6F7, 0x9FB3D9, 0xFFFFFF);
        double cx = k.Fx(0.38);
        double baseY = k.HillY(235, mid, cx) - k.Px(14);
        foreach (var (fx, hgt) in new[] { (0.24, 270.0), (0.29, 200.0), (0.52, 230.0), (0.57, 300.0) })
        {
            double x = k.Fx(fx);
            k.Pine(x, k.HillY(235, mid, x) - k.Px(12), k.Px(hgt), Hex(0x13254A), Hex(0xEAF1FF));
        }
        double hw = k.Px(240);
        var windows = k.House(cx, baseY, hw, 0x5B3A29, 0x3B2A26, 2, true, true, rng);
        double chimneyX = cx + hw * 0.23, chimneyY = baseY + hw * (0.62 + 0.46);
        k.BlurLayer(0.25, k.Px(9), c =>
        {
            for (int i = 0; i < 9; i++)
            {
                double t = i / 8.0;
                c.Circle(chimneyX + k.Px(60) * t + k.Px(14) * Math.Sin(t * 6), chimneyY + k.Px(150) * t, k.Px(10 + 26 * t), Hex(0xC8D3EA, 0.4 * (1 - t) + 0.05));
            }
        }, alpha: 0.7);
        k.BlurLayer(0.25, k.Px(28), c =>
        {
            foreach (var w in windows) c.Circle(w.X, w.Y, k.Px(42), Hex(0xFFB347, 0.75));
            using var spill = Ellipse(cx, baseY - k.Px(18), k.Px(220), k.Px(46));
            c.Fill(spill, Hex(0xFFB347, 0.35));
        }, SKBlendMode.Screen);
        var front = new (double, double, double)[] { (16, 0.5, 4.0), (7, 1.9, 0.6) };
        k.Hills(120, front, 0xEEF3FC, 0xB8C8E6, 0xFFFFFF);
        k.Sparkles(rng, StarCount(k, 0.3), 140);
        k.Pine(k.Fx(0.92), k.Px(30), k.Px(560), Hex(0x0E1C3C), Hex(0xEAF1FF));
        k.Pine(k.Fx(0.035), k.Px(20), k.Px(470), Hex(0x0E1C3C), Hex(0xEAF1FF));
        k.Snowfall(rng, StarCount(k, 0.3), (0.8, 2.2), (0.5, 0.9));
        k.Snowfall(rng, StarCount(k, 0.03), (5, 11), (0.25, 0.5), 3);
    }

    // 3 황금빛 설원 숲
    public static void Golden(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0xFDF0DC), (0.3, 0xF8D9AE), (0.55, 0xF0BE92), (0.8, 0xC4A7B8), (1, 0x8E9CC4));
        double sunX = k.Fx(0.7), sunY = k.Px(395);
        k.Sun(sunX, sunY, k.Px(38), 0xFFF7E6, 0xFFD59A, k.Px(760));
        var far = k.RidgePoints(rng, 420, 45, 0.55, (0.28, 130, 0.2), (0.82, 95, 0.18));
        k.Mountains(far, 0xD7BFB2, 0xE6D0C1, 0xFBF1EA, 470, rng, 0x7A5E5E, 0.14);
        k.Fog(405, 130, 0xFFF1DE, 0.75);
        k.Forest(rng, 140, (0, 1), (330, 365), (55, 110), 0xB9A196, 0xFFF1E3, 0.85);
        k.Fog(345, 90, 0xFFEBD3, 0.55);
        k.Forest(rng, 80, (0, 1), (250, 290), (100, 180), 0x7A6358, 0xFFEBD6);
        k.BlurLayer(0.25, k.Px(8), c =>
        {
            for (int i = 0; i < 7; i++)
            {
                double a = rng.Range(-2.6, -1.9);
                double spread = rng.Range(0.02, 0.05);
                double len = k.Px(1400);
                using var ray = new SKPath();
                ray.M(sunX, sunY);
                ray.L(sunX + Math.Cos(a - spread) * len, sunY + Math.Sin(a - spread) * len);
                ray.L(sunX + Math.Cos(a + spread) * len, sunY + Math.Sin(a + spread) * len);
                ray.Close();
                c.Fill(ray, Hex(0xFFE7BF, 0.5));
            }
        }, SKBlendMode.Screen, 0.4);
        var field = new (double, double, double)[] { (16, 0.6, 1.0), (6, 2.1, 2.2) };
        k.Hills(205, field, 0xFFF5E8, 0xE8D3C8, 0xFFFFFF);
        k.Fog(40, 140, 0x9AA0C8, 0.3);
        k.Forest(rng, 18, (0, 0.2), (110, 180), (260, 420), 0x3D3029, 0xFFE6C9);
        k.Forest(rng, 14, (0.86, 1), (110, 170), (240, 380), 0x3D3029, 0xFFE6C9);
        double deerX = k.Fx(0.78);
        k.Deer(deerX, k.HillY(205, field, deerX) - k.Px(10), k.Px(80), 0x3A2C25);
        k.Sparkles(rng, StarCount(k, 0.3), 200, 0xFFF6E3);
        k.Snowfall(rng, StarCount(k, 0.12), (0.8, 1.8), (0.4, 0.8));
    }

    // 4 얼어붙은 호수
    public static void Lake(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0.38, 0xF7D2C2), (0.52, 0xE9AABB), (0.72, 0x8F8DC4), (1, 0x2D3A6B));
        k.Stars(rng, StarCount(k, 0.06), 0.78, 0.9);
        k.Glow(k.Fx(0.5), k.Px(480), k.Px(650), 0xFFD9C7, 0.35);
        var ridge = k.RidgePoints(rng, 470, 55, 0.6, (0.24, 170, 0.18), (0.55, 230, 0.16), (0.8, 150, 0.17));
        k.Mountains(ridge, 0x6E6BA6, 0x938AB8, 0xF6E3EC, 560, rng, 0x2E2A5A, 0.3);
        k.Forest(rng, 90, (0, 1), (428, 440), (30, 70), 0x3E3A6A, 0xF4E6EF, 0.9);
        double shore = k.Px(430), lakeBottom = k.Px(130);
        var lakeRect = SKRect.Create(0, (float)lakeBottom, (float)k.W, (float)(shore - lakeBottom));
        k.C.Flush();
        using (var snapshot = k.Surface.Snapshot())
        {
            k.C.Save();
            k.C.ClipRect(lakeRect);
            k.C.Translate(0, (float)(2 * shore));
            k.C.Scale(1, -1);
            using var alpha = new SKPaint { Color = SKColors.White.WithAlpha(153), FilterQuality = SKFilterQuality.High };
            k.C.DrawUpright(snapshot, SKRect.Create(0, 0, (float)k.W, (float)k.H), alpha);
            k.C.Restore();
        }
        k.C.Clipped(lakeRect, () =>
        {
            k.C.FillLinear(new[] { Hex(0x7F95C9, 0.55), Hex(0xB7C3E6, 0.35) }, null, P(0, lakeBottom), P(0, shore));
            int sheen = StarCount(k, 0.06);
            for (int i = 0; i < sheen; i++)
            {
                double y = rng.Range(lakeBottom, shore), x = rng.Unit() * k.W, len = k.Px(rng.Range(40, 260));
                using var l = Line(x, y, x + len, y);
                k.C.Stroke(l, Hex(0xFFFFFF, rng.Range(0.08, 0.25)), k.Px(rng.Range(0.5, 1.5)));
            }
            for (int i = 0; i < 14; i++)
            {
                double px = rng.Unit() * k.W, py = rng.Range(lakeBottom, shore);
                using var crack = new SKPath();
                crack.M(px, py);
                for (int j = 0; j < 5; j++)
                {
                    px += k.Px(rng.Range(-50, 50));
                    py += k.Px(rng.Range(-20, 20));
                    crack.L(px, py);
                }
                k.C.Stroke(crack, Hex(0xFFFFFF, 0.22), k.Px(0.8));
            }
        });
        using (var strip = new SKPath())
        {
            strip.M(0, shore - k.Px(5));
            for (int i = 0; i <= 120; i++)
            {
                double fx = i / 120.0;
                strip.L(fx * k.W, shore + k.Px(3 + 3 * Math.Sin(fx * 13) + 2 * Math.Sin(fx * 31)));
            }
            strip.L(k.W, shore - k.Px(5));
            strip.Close();
            k.C.Fill(strip, Hex(0xF6EEF5));
            k.C.Clipped(strip, () => k.C.FillLinear(new[] { Hex(0xB9B4D8, 0.8), Hex(0xFFFFFF, 0) }, null, P(0, shore - k.Px(5)), P(0, shore + k.Px(4))));
        }
        var front = new (double, double, double)[] { (18, 0.55, 2.4), (6, 2.2, 0.3) };
        k.Hills(115, front, 0xF8F2F8, 0xD6D4EA, 0xFFFFFF);
        k.Pine(k.Fx(0.08), k.Px(60), k.Px(380), Hex(0x2E2A55), Hex(0xF7ECF4));
        k.Pine(k.Fx(0.14), k.Px(80), k.Px(240), Hex(0x2E2A55), Hex(0xF7ECF4));
        k.Sparkles(rng, StarCount(k, 0.25), 130);
    }

    // 5 눈 내리는 마을
    public static void Village(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0x36528C), (0.45, 0x1D2F5E), (1, 0x0A1532));
        k.Stars(rng, StarCount(k, 0.2), 0.5);
        k.Moon(k.Fx(0.14), k.Px(830), k.Px(36));
        var far = new (double, double, double)[] { (25, 0.9, 0.8), (10, 2.6, 2.0) };
        k.Hills(390, far, 0x2B4475, 0x23396A, 0x6F8BC0);
        k.Forest(rng, 120, (0, 1), (0, 0), (30, 70), 0x142449, 0x7C93C4, 0.75, x => k.HillY(390, far, x) - k.Px(3));
        var mid = new (double, double, double)[] { (14, 0.8, 1.4), (5, 3.0, 0.1) };
        k.Hills(300, mid, 0xD6E1F4, 0xA8BADB, 0xFFFFFF);
        uint[] walls = { 0x8C3B3B, 0x3B5B8C, 0x9A7B3E, 0x5B3B8C, 0x3B7C6B, 0xA0522D };
        uint[] roofs = { 0x4A2A2A, 0x2E2E44, 0x3D2B1F, 0x2F3B2A };
        var lights = new List<SKPoint>();
        var chimneys = new List<SKPoint>();
        for (int i = 0; i < 8; i++)
        {
            double x = k.Fx(0.07 + i * 0.12 + rng.Range(-0.02, 0.02));
            double wdt = k.Px(rng.Range(70, 100));
            double b = k.HillY(300, mid, x) - k.Px(6);
            bool chimney = rng.Unit() < 0.6;
            int count = 1 + (int)(rng.Unit() * 2);
            bool lit = rng.Unit() < 0.85;
            lights.AddRange(k.House(x, b, wdt, walls[i % walls.Length], roofs[i % roofs.Length], count, lit, chimney, rng));
            if (chimney) chimneys.Add(P(x + wdt * 0.23, b + wdt * 1.08));
        }
        double chx = k.Fx(0.63), chb = k.HillY(300, mid, chx) - k.Px(4), cw = k.Px(110);
        k.C.Rect(chx - cw / 2, chb, cw, cw * 0.9, Hex(0xD9D2C4));
        using (var steeple = new SKPath())
        {
            steeple.M(chx - cw * 0.22, chb + cw * 0.9);
            steeple.L(chx, chb + cw * 2.1);
            steeple.L(chx + cw * 0.22, chb + cw * 0.9);
            steeple.Close();
            k.C.Fill(steeple, Hex(0x3A3F5C));
        }
        using (var cross = new SKPath())
        {
            cross.M(chx, chb + cw * 2.1); cross.L(chx, chb + cw * 2.35);
            cross.M(chx - cw * 0.07, chb + cw * 2.25); cross.L(chx + cw * 0.07, chb + cw * 2.25);
            k.C.Stroke(cross, Hex(0xE8D9A8), k.Px(3));
        }
        k.C.Circle(chx, chb + cw * 0.6, cw * 0.12, Hex(0xFFD27A));
        lights.Add(P(chx, chb + cw * 0.6));
        var front = new (double, double, double)[] { (10, 0.7, 3.0), (4, 2.4, 1.2) };
        k.Hills(190, front, 0xE3EBF8, 0xB3C4E2, 0xFFFFFF);
        var frontHouses = new List<SKPoint>();
        for (int i = 0; i < 5; i++)
        {
            double x = k.Fx(0.12 + i * 0.19 + rng.Range(-0.02, 0.02));
            double wdt = k.Px(rng.Range(130, 170));
            double b = k.HillY(190, front, x) - k.Px(8);
            lights.AddRange(k.House(x, b, wdt, walls[(i + 3) % walls.Length], roofs[(i + 1) % roofs.Length], 2, true, i % 2 == 0, rng));
            if (i % 2 == 0) chimneys.Add(P(x + wdt * 0.23, b + wdt * 1.08));
            frontHouses.Add(P(x, b + wdt * 0.62));
        }
        uint[] bulbs = { 0xFF5A5A, 0xFFD84D, 0x5AD1FF, 0x7CFF8A };
        var bulbPoints = new List<(SKPoint, uint)>();
        for (int i = 0; i < frontHouses.Count - 1; i++)
        {
            var a = frontHouses[i];
            var b = frontHouses[i + 1];
            double ctlX = (a.X + b.X) / 2, ctlY = Math.Min(a.Y, b.Y) - k.Px(50);
            using var wire = new SKPath();
            wire.MoveTo(a);
            wire.Q(ctlX, ctlY, b.X, b.Y);
            k.C.Stroke(wire, Hex(0x1B1F33, 0.8), k.Px(1.2));
            for (int j = 1; j < 12; j++)
            {
                double t = j / 12.0;
                double px = (1 - t) * (1 - t) * a.X + 2 * (1 - t) * t * ctlX + t * t * b.X;
                double py = (1 - t) * (1 - t) * a.Y + 2 * (1 - t) * t * ctlY + t * t * b.Y;
                uint col = bulbs[(i * 11 + j) % bulbs.Length];
                k.C.Circle(px, py, k.Px(3.2), Hex(col));
                bulbPoints.Add((P(px, py), col));
            }
        }
        k.BlurLayer(0.25, k.Px(12), c =>
        {
            foreach (var p in lights) c.Circle(p.X, p.Y, k.Px(30), Hex(0xFFB347, 0.6));
            foreach (var (p, col) in bulbPoints) c.Circle(p.X, p.Y, k.Px(9), Hex(col, 0.8));
        }, SKBlendMode.Screen);
        k.BlurLayer(0.25, k.Px(8), c =>
        {
            foreach (var ch in chimneys)
                for (int i = 0; i < 7; i++)
                {
                    double t = i / 6.0;
                    c.Circle(ch.X + k.Px(40) * t, ch.Y + k.Px(110) * t, k.Px(6 + 18 * t), Hex(0xC8D3EA, 0.4 * (1 - t) + 0.05));
                }
        }, alpha: 0.55);
        var fg = new (double, double, double)[] { (12, 0.5, 0.9), (5, 1.8, 2.2) };
        k.Hills(85, fg, 0xEEF3FC, 0xBCCBE6, 0xFFFFFF);
        k.Pine(k.Fx(0.96), k.Px(20), k.Px(420), Hex(0x0E1C3C), Hex(0xEAF1FF));
        k.Sparkles(rng, StarCount(k, 0.25), 100);
        k.Snowfall(rng, StarCount(k, 0.55), (0.8, 2.4), (0.5, 0.95));
        k.Snowfall(rng, StarCount(k, 0.04), (5, 12), (0.25, 0.5), 3);
    }

    // 6 크리스마스 트리
    public static void Christmas(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0x2A3C70), (0.5, 0x142452), (1, 0x070F28));
        k.BlurLayer(0.25, k.Px(10), c =>
        {
            uint[] colors = { 0xFFC46B, 0xFF7A7A, 0x7AD7FF, 0xFFE9A8, 0xB98CFF };
            for (int i = 0; i < 70; i++)
            {
                double x = rng.Unit() * k.W, y = k.Px(rng.Range(300, 980));
                c.Circle(x, y, k.Px(rng.Range(14, 46)), Hex(colors[(int)(rng.Unit() * 5) % 5], rng.Range(0.2, 0.55)));
            }
        }, SKBlendMode.Screen, 0.9);
        var ground = new (double, double, double)[] { (10, 0.6, 1.1), (4, 2.0, 0.4) };
        k.Hills(165, ground, 0xE9F0FB, 0xAFC0E0, 0xFFFFFF);
        k.Forest(rng, 10, (0, 0.16), (140, 170), (150, 260), 0x0D1D3D, 0xDDE7F7);
        k.Forest(rng, 10, (0.84, 1), (140, 170), (150, 260), 0x0D1D3D, 0xDDE7F7);
        double cx = k.Fx(0.5), baseY = k.Px(150), H = k.Px(700);
        k.C.Rect(cx - H * 0.035, baseY, H * 0.07, H * 0.1, Hex(0x4A2E1E));
        const int tiers = 7;
        using var outline = new SKPath();
        var tierShapes = new List<(SKPath Path, double Bottom, double Apex, double Half)>();
        for (int i = 0; i < tiers; i++)
        {
            double t = (double)i / tiers;
            double bottomY = baseY + H * 0.08 + H * 0.84 * t;
            double apexY = Math.Min(baseY + H, bottomY + H * (0.24 - t * 0.08));
            double half = H * 0.38 * (1 - t * 0.82);
            var tier = new SKPath();
            tier.M(cx - half, bottomY);
            tier.L(cx, apexY);
            tier.L(cx + half, bottomY);
            tier.Q(cx, bottomY + half * 0.2, cx - half, bottomY);
            tier.Close();
            tierShapes.Add((tier, bottomY, apexY, half));
            outline.AddPath(tier);
        }
        foreach (var (tier, bottomY, apexY, half) in tierShapes)
        {
            k.C.Clipped(tier, () => k.C.FillLinear(new[] { Hex(0x0E4A28), Hex(0x1F7A45), Hex(0x2E9A58) }, new[] { 0f, 0.6f, 1f },
                                                   P(cx + half, bottomY), P(cx - half * 0.3, apexY)));
            using var l = Ellipse(cx - half * 0.88, bottomY + half * 0.04, half * 0.16, half * 0.06);
            k.C.Fill(l, Hex(0xF4F8FF));
            using var r = Ellipse(cx + half * 0.88, bottomY + half * 0.04, half * 0.16, half * 0.06);
            k.C.Fill(r, Hex(0xF4F8FF));
        }
        k.C.Clipped(outline, () =>
        {
            foreach (var (_, bottomY, apexY, half) in tierShapes.Take(tierShapes.Count - 1))
            {
                double y = bottomY + (apexY - bottomY) * 0.32;
                using var g = new SKPath();
                g.M(cx - half, y + half * 0.15);
                g.Q(cx, y - half * 0.25, cx + half, y + half * 0.05);
                k.C.Stroke(g, Hex(0xF5C451), k.Px(4));
                k.C.Stroke(g, Hex(0xFFF0B3, 0.6), k.Px(1.4));
            }
        });
        foreach (var t in tierShapes) t.Path.Dispose();
        double Inside(double y)
        {
            double t = (y - baseY - H * 0.08) / (H * 0.92);
            return Math.Max(0, H * 0.36 * (1 - t));
        }
        uint[] ballColors = { 0xE63946, 0xF4C430, 0x3A86FF, 0xF1F1F1, 0xC77DFF };
        for (int i = 0; i < 34; i++)
        {
            double y = baseY + H * rng.Range(0.14, 0.82);
            double half = Inside(y) * 0.8;
            double x = cx + rng.Range(-1, 1) * half;
            double r = k.Px(rng.Range(9, 15));
            using var ball = CirclePath(x, y, r);
            k.C.Fill(ball, Hex(ballColors[i % ballColors.Length]));
            k.C.Clipped(ball, () => k.C.FillRadial(new[] { Hex(0xFFFFFF, 0.65), Hex(0xFFFFFF, 0), Hex(0x000000, 0.3) }, new[] { 0f, 0.45f, 1f },
                                                   P(x, y), (float)r, P(x - r * 0.35, y + r * 0.35)));
            k.C.Rect(x - r * 0.25, y + r * 0.85, r * 0.5, r * 0.3, Hex(0xD4AF37));
        }
        var lightPts = new List<SKPoint>();
        for (int i = 0; i < 80; i++)
        {
            double y = baseY + H * rng.Range(0.12, 0.86);
            double x = cx + rng.Range(-1, 1) * Inside(y) * 0.9;
            k.C.Circle(x, y, k.Px(2.6), Hex(0xFFF3C4));
            lightPts.Add(P(x, y));
        }
        double sx = cx, sy = baseY + H + k.Px(18);
        using var star = new SKPath();
        for (int i = 0; i < 10; i++)
        {
            double a = i * Math.PI / 5 + Math.PI / 2;
            double rr = i % 2 == 0 ? k.Px(46) : k.Px(19);
            if (i == 0) star.M(sx + Math.Cos(a) * rr, sy + Math.Sin(a) * rr);
            else star.L(sx + Math.Cos(a) * rr, sy + Math.Sin(a) * rr);
        }
        star.Close();
        k.BlurLayer(0.25, k.Px(9), c =>
        {
            foreach (var p in lightPts) c.Circle(p.X, p.Y, k.Px(9), Hex(0xFFE7A0, 0.85));
            c.Circle(sx, sy, k.Px(62), Hex(0xFFE08A, 0.5));
        }, SKBlendMode.Screen);
        k.C.Clipped(star, () => k.C.FillLinear(new[] { Hex(0xFFF3B0), Hex(0xF5C451), Hex(0xD49A1F) }, new[] { 0f, 0.5f, 1f },
                                               P(sx - k.Px(30), sy + k.Px(40)), P(sx + k.Px(30), sy - k.Px(40))));
        k.C.Stroke(star, Hex(0xB07A12), k.Px(1.2));
        var gifts = new (double Fx, double Gw, double Gh, uint Body, uint Ribbon)[]
        {
            (-0.2, 90, 70, 0xE63946, 0xF5C451), (-0.08, 70, 55, 0x2A9D8F, 0xE63946), (0.07, 100, 60, 0x5E60CE, 0xFFFFFF), (0.2, 75, 80, 0xF4A261, 0x2E7D32),
        };
        foreach (var g in gifts)
        {
            var r = SKRect.Create((float)(cx + H * g.Fx - k.Px(g.Gw) / 2), (float)(baseY - k.Px(6)), (float)k.Px(g.Gw), (float)k.Px(g.Gh));
            k.C.Rect(r.Left, r.Top, r.Width, r.Height, Hex(g.Body));
            k.C.Clipped(r, () => k.C.FillLinear(new[] { Hex(0x000000, 0.25), Hex(0x000000, 0) }, null, P(r.Right, 0), P(r.MidX, 0)));
            k.C.Rect(r.MidX - k.Px(5), r.Top, k.Px(10), r.Height, Hex(g.Ribbon));
            k.C.Rect(r.Left, r.MidY - k.Px(5), r.Width, k.Px(10), Hex(g.Ribbon));
            using var bowL = Ellipse(r.MidX - k.Px(10), r.Bottom + k.Px(6), k.Px(11), k.Px(7));
            k.C.Fill(bowL, Hex(g.Ribbon));
            using var bowR = Ellipse(r.MidX + k.Px(10), r.Bottom + k.Px(6), k.Px(11), k.Px(7));
            k.C.Fill(bowR, Hex(g.Ribbon));
        }
        k.Sparkles(rng, StarCount(k, 0.25), 160);
        k.Snowfall(rng, StarCount(k, 0.35), (0.8, 2.2), (0.45, 0.9));
        k.Snowfall(rng, StarCount(k, 0.03), (5, 11), (0.2, 0.45), 3);
    }

    // 7 푸른 새벽 설산
    public static void Dawn(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0xDDE9F8), (0.25, 0xA9C6EC), (0.55, 0x4F78B8), (1, 0x0E1E45));
        k.Stars(rng, StarCount(k, 0.06), 0.8, 0.9);
        k.Glow(k.Fx(0.62), k.Px(470), k.Px(720), 0xFFFFFF, 0.28);
        var far = k.RidgePoints(rng, 430, 70, 0.6, (0.14, 170, 0.14), (0.44, 240, 0.15), (0.7, 300, 0.14), (0.9, 190, 0.12));
        k.Mountains(far, 0x9DB4DA, 0xB8CAE6, 0xF2F7FD, 480, rng, 0x3B5A93, 0.38);
        k.Fog(425, 150, 0xE3EDF9, 0.85);
        var mid = k.RidgePoints(rng, 300, 55, 0.56, (0.3, 160, 0.14), (0.63, 120, 0.12));
        k.Mountains(mid, 0x5E7DB3, 0x7D97C7, 0xE2EBF8, 360, rng, 0x203A6E, 0.4);
        k.Fog(290, 110, 0xDCE6F5, 0.55);
        k.Forest(rng, 170, (0, 1), (120, 170), (60, 150), 0x12223F, 0x4E6A9C, 0.6);
        var field = new (double, double, double)[] { (10, 0.7, 0.6), (5, 2.2, 1.9) };
        k.Hills(92, field, 0xCFDDF2, 0x93AACF, 0xEAF2FF);
        k.Sparkles(rng, StarCount(k, 0.2), 95);
    }

    // 8 자작나무 숲
    public static void Birches(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0xF2F4F7), (0.5, 0xE1E6EE), (1, 0xC9D1DD));
        for (int i = 0; i < 42; i++)
            k.Birch(rng.Unit() * k.W, k.Px(rng.Range(270, 320)), k.H, k.Px(rng.Range(5, 9)), rng, alpha: 0.35);
        k.Fog(300, 280, 0xF1F4F8, 0.9);
        for (int i = 0; i < 24; i++)
            k.Birch(rng.Unit() * k.W, k.Px(rng.Range(205, 245)), k.H, k.Px(rng.Range(10, 18)), rng, alpha: 0.75);
        k.Fog(220, 170, 0xF1F4F8, 0.55);
        var ground = new (double, double, double)[] { (6, 0.8, 0.4), (3, 2.6, 1.3) };
        k.Hills(215, ground, 0xF7F9FC, 0xDDE3EC, 0xFFFFFF);
        foreach (var fx in new[] { 0.06, 0.2, 0.37, 0.58, 0.71, 0.86, 0.97 })
            k.Birch(k.Fx(fx + rng.Range(-0.02, 0.02)), k.Px(rng.Range(40, 120)), k.H, k.Px(rng.Range(28, 58)), rng);
        foreach (var (fx, fy) in new[] { (0.82, 120.0), (0.9, 90.0), (0.12, 70.0) })
        {
            double rootX = k.Fx(fx);
            for (int i = 0; i < 5; i++)
            {
                double tipX = rootX + k.Px(rng.Range(-120, 120)), tipY = k.Px(fy + rng.Range(0, 110));
                using var twig = new SKPath();
                twig.M(rootX, 0);
                twig.Q((rootX + tipX) / 2 + k.Px(rng.Range(-30, 30)), tipY * 0.5, tipX, tipY);
                k.C.Stroke(twig, Hex(0x4A3B33), k.Px(2.2));
                for (int j = 0; j < 6; j++)
                {
                    double bx = tipX + k.Px(rng.Range(-12, 12)), by = tipY + k.Px(rng.Range(-14, 10));
                    k.C.Circle(bx, by, k.Px(rng.Range(3.5, 5.5)), Hex(0xC8102E));
                    k.C.Circle(bx - k.Px(1.2), by + k.Px(1.2), k.Px(1.1), Hex(0xFFFFFF, 0.6));
                }
                using var cap = Ellipse(tipX, tipY + k.Px(9), k.Px(12), k.Px(4));
                k.C.Fill(cap, Hex(0xFFFFFF, 0.95));
            }
        }
        k.Sparkles(rng, StarCount(k, 0.2), 210);
        k.Snowfall(rng, StarCount(k, 0.4), (1, 2.6), (0.55, 0.95));
        k.Snowfall(rng, StarCount(k, 0.03), (5, 10), (0.4, 0.7), 2.5);
    }

    // 9 은하수 설원
    public static void MilkyWay(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0x22315F), (0.3, 0x111A3D), (1, 0x04060F));
        SKPoint Band(double t) => P(k.Fx(-0.1 + 1.2 * t), k.Px(330 + 560 * t + 70 * Math.Sin(t * Math.PI * 1.4)));
        k.BlurLayer(0.25, k.Px(36), c =>
        {
            var palette = new (uint Color, double Alpha)[] { (0x5E4BA6, 0.32), (0x3F6FC0, 0.28), (0xC36B9F, 0.22), (0xE9C99B, 0.3) };
            for (int i = 0; i < 160; i++)
            {
                double t = rng.Unit();
                var p = Band(t);
                double off = k.Px(rng.Range(-90, 90));
                var (col, a) = palette[(int)(rng.Unit() * 4) % 4];
                double core = 1 - Math.Abs(t - 0.55) * 1.4;
                c.Circle(p.X + off * 0.4, p.Y + off, k.Px(rng.Range(50, 170)), Hex(col, a * Math.Max(0.3, core)));
            }
        }, SKBlendMode.Screen, 0.95);
        k.BlurLayer(0.25, k.Px(13), c =>
        {
            for (int i = 0; i < 90; i++)
            {
                double t = rng.Unit();
                var p = Band(t);
                double off = k.Px(rng.Range(-40, 40));
                using var e = Ellipse(p.X + off * 0.3, p.Y + off, k.Px(rng.Range(30, 90)), k.Px(rng.Range(6, 16)));
                c.Fill(e, Hex(0x1A1424, rng.Range(0.4, 0.9)));
            }
        }, SKBlendMode.Multiply, 0.38);
        k.BlurLayer(0.25, k.Px(18), c =>
        {
            var a = Band(0.55);
            c.Circle(a.X, a.Y, k.Px(160), Hex(0xF3D9B5, 0.45));
            var b = Band(0.5);
            c.Circle(b.X, b.Y, k.Px(110), Hex(0xFFE8C8, 0.4));
        }, SKBlendMode.Screen, 0.6);
        k.Stars(rng, StarCount(k, 0.5), 0.2, 1.1);
        int bandStars = StarCount(k, 2.2);
        for (int i = 0; i < bandStars; i++)
        {
            var p = Band(rng.Unit());
            double g = (rng.Unit() + rng.Unit() + rng.Unit() - 1.5) / 1.5;
            k.C.Circle(p.X + k.Px(g * 40), p.Y + k.Px(g * 110), k.Px(rng.Range(0.25, 0.8)), Hex(0xFFFFFF, rng.Range(0.3, 0.9)));
        }
        k.Fog(205, 170, 0x3F5A9A, 0.45);
        var hill = new (double, double, double)[] { (45, 0.55, 0.6), (8, 2.0, 1.5) };
        k.Hills(170, hill, 0x5E6E9E, 0x2F3A63, 0x9FB0DA);
        double tx = k.Fx(0.7);
        k.Pine(tx, k.HillY(170, hill, tx) - k.Px(6), k.Px(320), Hex(0x0A0F22), Hex(0x7E8FBC, 0.7));
        double tx2 = k.Fx(0.745);
        k.Pine(tx2, k.HillY(170, hill, tx2) - k.Px(6), k.Px(170), Hex(0x0A0F22), Hex(0x7E8FBC, 0.7));
        k.Sparkles(rng, StarCount(k, 0.2), 180, 0xCFD9F5);
    }

    // 10 분홍 노을 언덕
    public static void Pink(LandscapeKit k, SeededGenerator rng)
    {
        k.Sky((0, 0xFFE3C9), (0.25, 0xFFC9C2), (0.5, 0xF7A8C0), (0.8, 0xB48FD1), (1, 0x7D6BBF));
        k.Sun(k.Fx(0.5), k.Px(335), k.Px(62), 0xFFF4E3, 0xFFC1B0, k.Px(640));
        k.BlurLayer(0.25, k.Px(18), c =>
        {
            for (int i = 0; i < 26; i++)
            {
                using var cloud = Ellipse(rng.Unit() * k.W, k.Px(rng.Range(560, 880)), k.Px(rng.Range(80, 220)), k.Px(rng.Range(14, 34)));
                c.Fill(cloud, Hex(0xFFD6DE, rng.Range(0.35, 0.7)));
            }
        }, alpha: 0.75);
        var far = new (double, double, double)[] { (28, 0.8, 0.4), (10, 2.3, 1.9) };
        k.Hills(330, far, 0xE7A7C9, 0xE9B5CF, 0xFFE8F1);
        k.Forest(rng, 60, (0, 1), (0, 0), (25, 55), 0xB07FAE, 0xFFE6F0, 0.9, x => k.HillY(330, far, x) - k.Px(3));
        var mid = new (double, double, double)[] { (24, 0.6, 2.2), (8, 1.9, 0.7) };
        k.Hills(245, mid, 0xC99BD1, 0xD9AFD8, 0xFFEFF7);
        k.Forest(rng, 40, (0, 1), (0, 0), (45, 100), 0x8E6A9E, 0xFFF0F6, 1, x => k.HillY(245, mid, x) - k.Px(4));
        var near = new (double, double, double)[] { (20, 0.5, 4.1), (6, 2.6, 1.1) };
        k.Hills(150, near, 0xF5D9E6, 0xE2C3DA, 0xFFFFFF);
        var fg = new (double, double, double)[] { (12, 0.45, 1.0), (4, 2.0, 2.6) };
        k.Hills(70, fg, 0xFFF5F8, 0xEED9E6, 0xFFFFFF);
        k.Pine(k.Fx(0.09), k.Px(40), k.Px(300), Hex(0x6E4E7E), Hex(0xFFF2F7));
        k.Pine(k.Fx(0.9), k.Px(30), k.Px(360), Hex(0x6E4E7E), Hex(0xFFF2F7));
        for (int i = 0; i < 9; i++)
        {
            double px = k.Fx(rng.Range(0.25, 0.7)), py = k.Px(rng.Range(600, 820)), s = k.Px(rng.Range(6, 12));
            using var bird = new SKPath();
            bird.M(px - s, py + s * 0.4);
            bird.Q(px - s * 0.5, py + s * 0.6, px, py);
            bird.Q(px + s * 0.5, py + s * 0.6, px + s, py + s * 0.4);
            k.C.Stroke(bird, Hex(0x6B4E7A, 0.7), k.Px(1.6));
        }
        k.Sparkles(rng, StarCount(k, 0.25), 150, 0xFFF6FA);
    }
}
