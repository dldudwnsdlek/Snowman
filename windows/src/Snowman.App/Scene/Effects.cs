using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace Snowman.App.Scene;

internal enum EffectKind { Puff, Sparkle, Text, Debris }

internal sealed class Effect
{
    public EffectKind Kind;
    public double X, Y, Vx, Vy, Size, Rotation, Spin, Age, Delay, Life, Scale = 1;
    public ImageSource? Image;
    public double ImageW, ImageH;
    public Geometry? Text;
    public double TextW, TextH;
}

/// <summary>Short-lived visual effects: snow puffs, sparkles, "와장창!" and flying debris.</summary>
internal sealed class EffectSystem
{
    private static readonly Brush TextFill = SpriteDraw.Frozen(Colors.White);
    private static readonly Pen TextOutline = SpriteDraw.FrozenPen(Color.FromRgb(0x2B, 0x52, 0xB8), 5);
    private readonly List<Effect> _items = new();

    public void Puff(double x, double y, double size) => _items.Add(new Effect
    {
        Kind = EffectKind.Puff, X = x, Y = y, Size = size, Life = 0.45, Rotation = Random.Shared.NextDouble() * Math.PI * 2,
    });

    public void Sparkles(double cx, double cy, double radius, int count)
    {
        for (int i = 0; i < count; i++)
        {
            double a = (double)i / count * 2 * Math.PI + Random.Shared.NextDouble() * 0.6;
            double d = radius * (0.6 + Random.Shared.NextDouble() * 0.55);
            _items.Add(new Effect
            {
                Kind = EffectKind.Sparkle, X = cx + Math.Cos(a) * d, Y = cy + Math.Sin(a) * d,
                Size = 15 * (0.7 + Random.Shared.NextDouble() * 0.6), Delay = i * 0.04, Life = i * 0.04 + 0.46,
                Rotation = Random.Shared.NextDouble(),
            });
        }
    }

    public void CrashText(double x, double y, double sceneW, double sceneH, string text = "와장창!", double size = 30)
    {
        var ft = new FormattedText(text, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight,
            new Typeface(new FontFamily("Malgun Gothic"), FontStyles.Normal, FontWeights.Black, FontStretches.Normal),
            size, TextFill, 1.0);
        var geo = ft.BuildGeometry(new Point(0, 0));
        geo.Freeze();
        _items.Add(new Effect
        {
            Kind = EffectKind.Text,
            X = Math.Clamp(x, 80, Math.Max(80, sceneW - 80)),
            Y = Math.Clamp(y, 40, Math.Max(40, sceneH - 70)),
            Life = 1.0, Rotation = Random.Shared.NextDouble() * 0.36 - 0.18,
            Text = geo, TextW = ft.WidthIncludingTrailingWhitespace, TextH = ft.Height,
        });
    }

    public void Debris(ImageSource img, double w, double h, double x, double y, double vx, double vy, double spin, double scale, double rotation) =>
        _items.Add(new Effect
        {
            Kind = EffectKind.Debris, Image = img, ImageW = w, ImageH = h, X = x, Y = y, Vx = vx, Vy = vy, Spin = spin,
            Scale = scale, Rotation = rotation, Life = 1.4,
        });

    public void Update(double dt)
    {
        for (int i = _items.Count - 1; i >= 0; i--)
        {
            var e = _items[i];
            e.Age += dt;
            if (e.Kind == EffectKind.Debris)
            {
                e.Vy -= 1470 * dt;
                e.Vx -= e.Vx * 0.15 * dt;
                e.Vy -= e.Vy * 0.15 * dt;
                e.X += e.Vx * dt;
                e.Y += e.Vy * dt;
                e.Rotation += e.Spin * dt;
            }
            if (e.Age >= e.Life) _items.RemoveAt(i);
        }
    }

    public void Draw(DrawingContext dc)
    {
        foreach (var e in _items)
        {
            switch (e.Kind)
            {
                case EffectKind.Puff:
                {
                    double k = e.Age / e.Life;
                    double s = e.Size * (0.4 + 1.1 * k);
                    var m = SpriteDraw.Local(40, 40, 0.5, 0.5, s / 40, s / 40, e.Rotation, e.X, e.Y);
                    SpriteDraw.Image(dc, Sprites.Puff, 40, 40, m, 0.95 * (1 - k));
                    break;
                }
                case EffectKind.Sparkle:
                {
                    double t = e.Age - e.Delay;
                    if (t < 0) break;
                    double scale = t < 0.16 ? t / 0.16 : Math.Max(0, 1 - (t - 0.16) / 0.3);
                    double alpha = t < 0.16 ? 1 : Math.Max(0, 1 - (t - 0.16) / 0.3);
                    double rot = e.Rotation + Math.Min(t, 0.6) / 0.6 * 1.2;
                    var m = SpriteDraw.Local(18, 18, 0.5, 0.5, e.Size / 18 * scale, e.Size / 18 * scale, rot, e.X, e.Y);
                    SpriteDraw.Image(dc, Sprites.Sparkle, 18, 18, m, alpha);
                    break;
                }
                case EffectKind.Text when e.Text is not null:
                {
                    double t = e.Age;
                    double scale = t < 0.12 ? 0.3 + 0.95 * (t / 0.12) : t < 0.2 ? 1.25 - 0.25 * ((t - 0.12) / 0.08) : 1;
                    double rise = t < 0.2 ? 0 : 34 * Math.Min(1, (t - 0.2) / 0.8);
                    double alpha = t < 0.65 ? 1 : Math.Max(0, 1 - (t - 0.65) / 0.35);
                    var m = SpriteDraw.Local(e.TextW, e.TextH, 0.5, 0.5, scale, scale, e.Rotation, e.X, e.Y + rise);
                    dc.PushTransform(new MatrixTransform(m));
                    dc.PushOpacity(alpha);
                    dc.DrawGeometry(TextFill, TextOutline, e.Text);
                    dc.DrawGeometry(TextFill, null, e.Text);
                    dc.Pop();
                    dc.Pop();
                    break;
                }
                case EffectKind.Debris when e.Image is not null:
                {
                    double alpha = e.Age < 0.9 ? 1 : Math.Max(0, 1 - (e.Age - 0.9) / 0.5);
                    var m = SpriteDraw.Local(e.ImageW, e.ImageH, 0.5, 0.5, e.Scale, e.Scale, e.Rotation, e.X, e.Y);
                    SpriteDraw.Image(dc, e.Image, e.ImageW, e.ImageH, m, alpha);
                    break;
                }
            }
        }
    }
}
