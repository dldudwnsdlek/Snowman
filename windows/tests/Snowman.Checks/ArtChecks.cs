using SkiaSharp;
using Snowman.Art;
using Snowman.Core;
using static Snowman.Checks.Harness;

namespace Snowman.Checks;

internal static class ArtChecks
{
    public static double OpaqueFraction(SKImage img)
    {
        using var bmp = SKBitmap.FromImage(img);
        int count = 0;
        var pixels = bmp.Pixels;
        foreach (var px in pixels) if (px.Alpha > 10) count++;
        return (double)count / pixels.Length;
    }

    public static void Run()
    {
        var required = new HashSet<SnowmanPart>
        {
            SnowmanPart.Body, SnowmanPart.Head, SnowmanPart.LeftArm, SnowmanPart.RightArm, SnowmanPart.Eyes, SnowmanPart.EyesClosed,
            SnowmanPart.Nose, SnowmanPart.Mouth, SnowmanPart.Scarf, SnowmanPart.ScarfTail, SnowmanPart.Hat,
        };
        foreach (var style in SnowmanStyleInfo.All)
        {
            var parts = SnowmanArt.Parts(style);
            Check($"spritesRender.{style}.hasCoreParts", required.IsSubsetOf(parts));
            foreach (var part in parts)
            {
                var img = SnowmanArt.Part(part, style, 2);
                if (img is null) { Check($"spritesRender.{style}.{part}.exists", false); continue; }
                Check($"spritesRender.{style}.{part}.opaque", OpaqueFraction(img.Image) > 0.01);
            }
            using var whole = SnowmanArt.Composite(style, 120, 2);
            Check($"spritesRender.{style}.composite", OpaqueFraction(whole) > 0.15, $"{OpaqueFraction(whole)}");
        }
        var sprites = new (string, SKImage)[]
        {
            ("flake", SpriteArt.Flake(8, 2)), ("clump", SpriteArt.Clump(10, 2)), ("mitten", SpriteArt.Mitten(28, 2)),
            ("snowball", SpriteArt.Snowball(30, 2)), ("plow", SpriteArt.Plow(2)), ("plowWheel", SpriteArt.PlowWheel(2)),
            ("plowBeacon", SpriteArt.PlowBeacon(2)), ("puff", SpriteArt.Puff(2)), ("sparkle", SpriteArt.Sparkle(2)),
            ("trayIcon", SpriteArt.TraySnowflake(32)),
        };
        foreach (var (name, img) in sprites) Check($"spritesRender.{name}", OpaqueFraction(img) > 0.02);
    }
}
