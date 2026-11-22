using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Media;

namespace Snowman.App;

internal enum SoundEffect { Pop, Whoosh, Crash, Thud, Horn, Done, Tink }

/// <summary>Tiny synthesised sound effects (no audio files needed), gated by 효과음 and throttled.</summary>
internal static class Sound
{
    private const int Rate = 22050;
    private static readonly Dictionary<(SoundEffect, int), byte[]> Cache = new();
    private static readonly Dictionary<SoundEffect, double> LastPlayed = new();
    private static readonly Stopwatch Clock = Stopwatch.StartNew();
    private static SoundPlayer? _player;

    public static bool Enabled { get; set; } = true;

    public static void Play(SoundEffect effect, double volume = 0.35)
    {
        if (!Enabled) return;
        double now = Clock.Elapsed.TotalSeconds;
        if (LastPlayed.TryGetValue(effect, out double last) && now - last < 0.18) return;
        LastPlayed[effect] = now;
        try
        {
            int bucket = (int)Math.Round(Math.Clamp(volume, 0, 1) * 20);
            if (!Cache.TryGetValue((effect, bucket), out var wav))
            {
                wav = Synthesize(effect, bucket / 20.0);
                Cache[(effect, bucket)] = wav;
            }
            var player = new SoundPlayer(new MemoryStream(wav));
            player.Play();
            _player = player;
        }
        catch (Exception e)
        {
            Program.Log("sound failed: " + e.Message);
        }
    }

    private static byte[] Synthesize(SoundEffect e, double volume)
    {
        double duration = e switch
        {
            SoundEffect.Pop => 0.09,
            SoundEffect.Whoosh => 0.55,
            SoundEffect.Crash => 0.5,
            SoundEffect.Thud => 0.16,
            SoundEffect.Horn => 0.5,
            SoundEffect.Done => 0.65,
            _ => 0.18,
        };
        int n = (int)(Rate * duration);
        var s = new double[n];
        var rng = new Random(7);
        double lp = 0;
        for (int i = 0; i < n; i++)
        {
            double t = (double)i / Rate;
            double x;
            switch (e)
            {
                case SoundEffect.Pop:
                    x = Math.Sin(2 * Math.PI * (900 - 500 * t / duration) * t) * Math.Exp(-t * 45);
                    break;
                case SoundEffect.Whoosh:
                {
                    lp += (rng.NextDouble() * 2 - 1 - lp) * 0.08;
                    double env = Math.Sin(Math.PI * t / duration);
                    x = lp * 3 * env * env;
                    break;
                }
                case SoundEffect.Crash:
                    x = (rng.NextDouble() * 2 - 1) * Math.Exp(-t * 9) * 0.7
                        + (Math.Sin(2 * Math.PI * 2600 * t) + 0.6 * Math.Sin(2 * Math.PI * 3700 * t)) * Math.Exp(-t * 14) * 0.25;
                    break;
                case SoundEffect.Thud:
                    x = Math.Sin(2 * Math.PI * (140 - 80 * t / duration) * t) * Math.Exp(-t * 22) + (rng.NextDouble() * 2 - 1) * Math.Exp(-t * 60) * 0.3;
                    break;
                case SoundEffect.Horn:
                {
                    double env = Beep(t, 0, 0.18) + Beep(t, 0.25, 0.43);
                    double f = 523;
                    x = env * 0.6 * (Math.Sin(2 * Math.PI * f * t) + Math.Sin(2 * Math.PI * 3 * f * t) / 3 + Math.Sin(2 * Math.PI * 5 * f * t) / 5);
                    break;
                }
                case SoundEffect.Done:
                {
                    x = 0;
                    double[] notes = { 523.25, 659.25, 783.99 };
                    for (int k = 0; k < notes.Length; k++)
                    {
                        double start = k * 0.12;
                        if (t >= start) x += Math.Sin(2 * Math.PI * notes[k] * (t - start)) * Math.Exp(-(t - start) * 6) * 0.6;
                    }
                    break;
                }
                default:
                    x = Math.Sin(2 * Math.PI * 2093 * t) * Math.Exp(-t * 25) + 0.3 * Math.Sin(2 * Math.PI * 4186 * t) * Math.Exp(-t * 35);
                    break;
            }
            s[i] = x;
        }
        double peak = 1e-6;
        foreach (var v in s) peak = Math.Max(peak, Math.Abs(v));
        double gain = 0.9 * volume / peak;
        using var ms = new MemoryStream();
        using var w = new BinaryWriter(ms);
        int dataBytes = n * 2;
        w.Write("RIFF"u8.ToArray());
        w.Write(36 + dataBytes);
        w.Write("WAVEfmt "u8.ToArray());
        w.Write(16);
        w.Write((short)1);
        w.Write((short)1);
        w.Write(Rate);
        w.Write(Rate * 2);
        w.Write((short)2);
        w.Write((short)16);
        w.Write("data"u8.ToArray());
        w.Write(dataBytes);
        foreach (var v in s) w.Write((short)Math.Clamp(v * gain * short.MaxValue, short.MinValue, short.MaxValue));
        w.Flush();
        return ms.ToArray();
    }

    private static double Beep(double t, double start, double end)
    {
        if (t < start || t > end) return 0;
        return Math.Min(1, Math.Min((t - start) / 0.005, (end - t) / 0.005));
    }
}
