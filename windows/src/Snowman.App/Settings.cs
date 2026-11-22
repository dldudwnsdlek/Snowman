using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Snowman.Core;

namespace Snowman.App;

/// <summary>User preferences, saved as JSON in %APPDATA%\Snowman.</summary>
internal sealed class Settings
{
    public string Amount { get; set; } = "normal";
    public bool Paused { get; set; }
    public bool AccumulateOnWindows { get; set; } = true;
    public bool SoundOn { get; set; } = true;
    public int? CurrentWallpaper { get; set; }

    [JsonIgnore]
    public SnowAmount AmountValue
    {
        get => SnowAmountInfo.FromKey(Amount) ?? SnowAmount.Normal;
        set => Amount = value.Key();
    }

    public static string Folder { get; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Snowman");

    private static string FilePath => Path.Combine(Folder, "settings.json");

    public static Settings Load()
    {
        try
        {
            if (File.Exists(FilePath)) return JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
        }
        catch (Exception e)
        {
            Program.Log("settings load failed: " + e.Message);
        }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Folder);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception e)
        {
            Program.Log("settings save failed: " + e.Message);
        }
    }
}
