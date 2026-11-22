using System.Collections.Generic;
using System.IO;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using SkiaSharp;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App;

/// <summary>Every sprite, drawn once with SkiaSharp and turned into frozen WPF bitmaps.</summary>
internal static class Sprites
{
    public const double ArtScale = 2;

    public static BitmapSource ToBitmap(SKImage img)
    {
        using var bmp = SKBitmap.FromImage(img);
        var bs = BitmapSource.Create(bmp.Width, bmp.Height, 96, 96, PixelFormats.Pbgra32, null, bmp.GetPixels(), bmp.ByteCount, bmp.RowBytes);
        bs.Freeze();
        return bs;
    }

    public static BitmapSource Take(SKImage img)
    {
        var b = ToBitmap(img);
        img.Dispose();
        return b;
    }

    public static System.Drawing.Bitmap ToGdi(SKImage img)
    {
        using var data = img.Encode(SKEncodedImageFormat.Png, 100);
        using var ms = new MemoryStream(data.ToArray());
        using var tmp = new System.Drawing.Bitmap(ms);
        return new System.Drawing.Bitmap(tmp);
    }

    /// <summary>Flakes at six opacities (0.55 … 1.0).</summary>
    public static readonly BitmapSource[] Flakes = BuildFlakes();
    public static readonly BitmapSource Clump = Take(SpriteArt.Clump(12, ArtScale));
    public static readonly BitmapSource Mitten = Take(SpriteArt.Mitten(30, ArtScale));
    public static readonly BitmapSource Snowball = Take(SpriteArt.Snowball(60, ArtScale));
    public static readonly BitmapSource Plow = Take(SpriteArt.Plow(ArtScale));
    public static readonly BitmapSource PlowWheel = Take(SpriteArt.PlowWheel(ArtScale));
    public static readonly BitmapSource PlowBeacon = Take(SpriteArt.PlowBeacon(ArtScale));
    public static readonly BitmapSource BeaconGlow = Take(SpriteArt.Glow(16, 0xFFB703, ArtScale));
    public static readonly BitmapSource Puff = Take(SpriteArt.Puff(ArtScale));
    public static readonly BitmapSource Sparkle = Take(SpriteArt.Sparkle(ArtScale));

    private static BitmapSource[] BuildFlakes()
    {
        var result = new BitmapSource[6];
        for (int i = 0; i < 6; i++) result[i] = Take(SpriteArt.Flake(10, ArtScale, 0.55 + 0.09 * i));
        return result;
    }

    public static BitmapSource FlakeFor(double alpha)
    {
        int i = (int)System.Math.Round((alpha - 0.55) / 0.09);
        return Flakes[System.Math.Clamp(i, 0, 5)];
    }

    private static readonly Dictionary<SnowmanStyle, Dictionary<SnowmanPart, (BitmapSource Bitmap, PartImage Info)>> PartCache = new();

    /// <summary>Snowman parts drawn at 2.2× reference size so big snowmen stay crisp.</summary>
    public static Dictionary<SnowmanPart, (BitmapSource Bitmap, PartImage Info)> PartsFor(SnowmanStyle style)
    {
        if (PartCache.TryGetValue(style, out var cached)) return cached;
        var result = new Dictionary<SnowmanPart, (BitmapSource, PartImage)>();
        foreach (var part in SnowmanArt.Parts(style))
        {
            var p = SnowmanArt.Part(part, style, ArtScale * 2.2);
            if (p is null) continue;
            result[part] = (ToBitmap(p.Image), p);
            p.Image.Dispose();
        }
        PartCache[style] = result;
        return result;
    }
}
