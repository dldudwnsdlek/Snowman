using System.Text.Json.Serialization;

namespace Snowman.Core;

/// <summary>The wallpaper the desktop had before Snowman changed it.</summary>
public sealed record SavedWallpaper(string Path, string? Style, string? Tile, string? Backup);

/// <summary>
/// Remembers the original wallpaper exactly once, so "원래 배경화면으로" restores it even after several
/// winter wallpapers were tried or the app was restarted.
/// </summary>
public sealed class WallpaperMemory
{
    public Dictionary<string, SavedWallpaper> Originals { get; set; } = new();

    [JsonIgnore] public bool IsEmpty => Originals.Count == 0;

    public void RememberIfNeeded(string key, SavedWallpaper saved)
    {
        if (!Originals.ContainsKey(key)) Originals[key] = saved;
    }

    public Dictionary<string, SavedWallpaper> TakeAll()
    {
        var copy = new Dictionary<string, SavedWallpaper>(Originals);
        Originals.Clear();
        return copy;
    }
}
