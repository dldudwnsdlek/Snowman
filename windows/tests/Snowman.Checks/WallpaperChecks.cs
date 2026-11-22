using SkiaSharp;
using Snowman.Art;
using Snowman.Core;
using static Snowman.Checks.Harness;

namespace Snowman.Checks;

internal static class WallpaperChecks
{
    private static byte[] Thumb(SKImage img, int w = 16, int h = 10)
    {
        using var bmp = new SKBitmap(new SKImageInfo(w, h, SKColorType.Rgba8888, SKAlphaType.Premul));
        using var canvas = new SKCanvas(bmp);
        using var paint = new SKPaint { FilterQuality = SKFilterQuality.Medium };
        canvas.DrawImage(img, new SKRect(0, 0, w, h), paint);
        canvas.Flush();
        return bmp.Bytes;
    }

    private static double MeanAbsDiff(byte[] a, byte[] b)
    {
        long sum = 0; int n = 0;
        for (int i = 0; i < Math.Min(a.Length, b.Length); i++)
        {
            if (i % 4 == 3) continue;
            sum += Math.Abs(a[i] - b[i]); n++;
        }
        return (double)sum / n;
    }

    public static void Run()
    {
        {
            var m = new WallpaperMemory();
            m.RememberIfNeeded("1", new SavedWallpaper(@"C:\A.jpg", "10", "0", null));
            m.RememberIfNeeded("1", new SavedWallpaper(@"C:\B.jpg", "2", "0", null));
            Check("originalWallpaperSavedOnce.kept", m.Originals["1"].Path == @"C:\A.jpg");
            var all = m.TakeAll();
            Check("originalWallpaperSavedOnce.taken", all.Count == 1 && m.IsEmpty);
        }
        {
            var m = new WallpaperMemory();
            m.RememberIfNeeded("2", new SavedWallpaper("u", null, null, null));
            var json = System.Text.Json.JsonSerializer.Serialize(m);
            var back = System.Text.Json.JsonSerializer.Deserialize<WallpaperMemory>(json);
            Check("wallpaperMemoryCodable", back?.Originals["2"].Path == "u", json);
        }
        Check("wallpaperCount", WallpaperArt.All.Length == 10);
        Check("wallpaperTitles", WallpaperArt.All.Select(w => w.Title()).SequenceEqual(new[]
        {
            "오로라의 밤", "달빛 오두막", "황금빛 설원 숲", "얼어붙은 호수", "눈 내리는 마을",
            "크리스마스 트리", "푸른 새벽 설산", "자작나무 숲", "은하수 설원", "분홍 노을 언덕",
        }));
        {
            var thumbs = WallpaperArt.All.Select(w => { using var img = w.Render(320, 200); return Thumb(img); }).ToList();
            double minDiff = double.MaxValue;
            for (int i = 0; i < thumbs.Count; i++)
                for (int j = i + 1; j < thumbs.Count; j++) minDiff = Math.Min(minDiff, MeanAbsDiff(thumbs[i], thumbs[j]));
            Check("wallpapersRenderDistinct", minDiff > 8, $"min pairwise diff {minDiff}");
        }
        {
            using var a = WinterWallpaper.AuroraNight.Render(320, 200);
            using var b = WinterWallpaper.AuroraNight.Render(320, 200);
            Check("wallpaperDeterministic", Thumb(a, 64, 40).SequenceEqual(Thumb(b, 64, 40)));
            using var img = WinterWallpaper.MoonlitCabin.Render(302, 196);
            Check("wallpaperSize", img.Width == 302 && img.Height == 196);
        }
    }
}
