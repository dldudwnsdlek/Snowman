using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;
using SkiaSharp;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App;

/// <summary>Renders, caches, applies and restores the winter wallpapers.</summary>
internal sealed class WallpaperManager
{
    /// <summary>Bump when the wallpaper art changes so cached files are re-rendered.</summary>
    private const int ArtVersion = 1;
    private const string Key = "desktop";
    private static readonly object FileLock = new();
    private readonly Settings _settings;

    public WallpaperManager(Settings settings) => _settings = settings;

    private static string Folder
    {
        get
        {
            var dir = Path.Combine(Program.DataFolder, "Wallpapers");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    private static string MemoryPath => Path.Combine(Settings.Folder, "wallpaper-memory.json");

    private static WallpaperMemory LoadMemory()
    {
        try
        {
            if (File.Exists(MemoryPath)) return JsonSerializer.Deserialize<WallpaperMemory>(File.ReadAllText(MemoryPath)) ?? new WallpaperMemory();
        }
        catch (Exception e)
        {
            Program.Log("wallpaper memory load failed: " + e.Message);
        }
        return new WallpaperMemory();
    }

    private static void SaveMemory(WallpaperMemory m)
    {
        Directory.CreateDirectory(Settings.Folder);
        File.WriteAllText(MemoryPath, JsonSerializer.Serialize(m));
    }

    public bool HasSavedOriginal => !LoadMemory().IsEmpty;

    /// <summary>Largest monitor size in pixels; Windows fills the other monitors from it.</summary>
    private static (int W, int H) TargetSize()
    {
        var screens = System.Windows.Forms.Screen.AllScreens;
        var best = screens.OrderByDescending(s => (long)s.Bounds.Width * s.Bounds.Height).First().Bounds;
        return (Math.Max(640, best.Width), Math.Max(400, best.Height));
    }

    /// <summary>Rounded 64×40 previews for the menu, made off the UI thread.</summary>
    public void MakeThumbnails(Action<Dictionary<int, System.Drawing.Bitmap>> done)
    {
        var dispatcher = System.Windows.Application.Current.Dispatcher;
        Task.Run(() =>
        {
            var result = new Dictionary<int, System.Drawing.Bitmap>();
            foreach (var w in WallpaperArt.All)
            {
                try
                {
                    using var img = w.Render(128, 80);
                    using var rounded = Draw.Image(64, 40, 2, c =>
                    {
                        using var clip = Draw.RoundRect(0, 0, 64, 40, 6, 6);
                        c.Clipped(clip, () => c.DrawUpright(img, SKRect.Create(0, 0, 64, 40)));
                    });
                    result[(int)w] = Sprites.ToGdi(rounded);
                }
                catch (Exception e)
                {
                    Program.Log("thumbnail failed: " + e.Message);
                }
            }
            dispatcher.BeginInvoke(new Action(() => done(result)));
        });
    }

    /// <summary>Renders all ten in the background shortly after start so choosing one is instant.</summary>
    public void PrerenderAll()
    {
        var size = TargetSize();
        Task.Run(async () =>
        {
            await Task.Delay(6000);
            foreach (var w in WallpaperArt.All)
            {
                try { EnsureFile(w, size); }
                catch (Exception e) { Program.Log("prerender failed: " + e.Message); }
            }
        });
    }

    public void Apply(int tag)
    {
        if (!Enum.IsDefined(typeof(WinterWallpaper), tag)) return;
        var w = (WinterWallpaper)tag;
        var mem = LoadMemory();
        string current = CurrentWallpaperPath();
        if (!current.StartsWith(Folder, StringComparison.OrdinalIgnoreCase))
        {
            string? backup = null;
            try
            {
                if (File.Exists(current))
                {
                    string ext = Path.GetExtension(current);
                    backup = Path.Combine(Program.DataFolder, "original-wallpaper" + (string.IsNullOrEmpty(ext) ? ".jpg" : ext));
                    if (!mem.Originals.ContainsKey(Key)) File.Copy(current, backup, true);
                }
            }
            catch (Exception e)
            {
                Program.Log("wallpaper backup failed: " + e.Message);
                backup = null;
            }
            using var desktop = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop");
            mem.RememberIfNeeded(Key, new SavedWallpaper(current, desktop?.GetValue("WallpaperStyle") as string, desktop?.GetValue("TileWallpaper") as string, backup));
            SaveMemory(mem);
        }
        _settings.CurrentWallpaper = tag;
        _settings.Save();
        var size = TargetSize();
        var dispatcher = System.Windows.Application.Current.Dispatcher;
        Task.Run(() =>
        {
            try
            {
                string path = EnsureFile(w, size);
                dispatcher.BeginInvoke(new Action(() => SetWallpaper(path, "10", "0")));
            }
            catch (Exception e)
            {
                Program.Log("wallpaper apply failed: " + e);
            }
        });
    }

    public void RestoreOriginal()
    {
        var mem = LoadMemory();
        var originals = mem.TakeAll();
        SaveMemory(mem);
        if (originals.TryGetValue(Key, out var saved))
        {
            bool usable = saved.Path.Length > 0 && File.Exists(saved.Path)
                          && !saved.Path.Contains("TranscodedWallpaper", StringComparison.OrdinalIgnoreCase);
            string path = usable ? saved.Path : (saved.Backup is string b && File.Exists(b) ? b : saved.Path);
            SetWallpaper(path, saved.Style ?? "10", saved.Tile ?? "0");
        }
        _settings.CurrentWallpaper = null;
        _settings.Save();
    }

    private static string CurrentWallpaperPath()
    {
        var sb = new StringBuilder(1024);
        Native.SystemParametersInfo(Native.SPI_GETDESKWALLPAPER, (uint)sb.Capacity, sb, 0);
        return sb.ToString();
    }

    private static void SetWallpaper(string path, string style, string tile)
    {
        try
        {
            using (var desktop = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop", true))
            {
                desktop?.SetValue("WallpaperStyle", style);
                desktop?.SetValue("TileWallpaper", tile);
            }
            Native.SystemParametersInfo(Native.SPI_SETDESKWALLPAPER, 0, path, Native.SPIF_UPDATEINIFILE | Native.SPIF_SENDCHANGE);
        }
        catch (Exception e)
        {
            Program.Log("set wallpaper failed: " + e.Message);
        }
    }

    /// <summary>Returns the cached JPEG, rendering it first if needed.</summary>
    private static string EnsureFile(WinterWallpaper w, (int W, int H) size)
    {
        string path = Path.Combine(Folder, $"{w.FileStem()}-v{ArtVersion}-{size.W}x{size.H}.jpg");
        lock (FileLock)
        {
            if (File.Exists(path)) return path;
            using var image = w.Render(size.W, size.H);
            using var data = image.Encode(SKEncodedImageFormat.Jpeg, 93);
            string tmp = path + ".part";
            File.WriteAllBytes(tmp, data.ToArray());
            File.Move(tmp, path, true);
            return path;
        }
    }
}
