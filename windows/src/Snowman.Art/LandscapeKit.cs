using SkiaSharp;
using Snowman.Core;
using static Snowman.Art.Col;
using static Snowman.Art.Draw;

namespace Snowman.Art;

/// <summary>
/// Drawing helpers for the winter wallpapers. Canvas is in pixels, origin bottom-left (y up);
/// vertical sizes are given in units of 1/1000 of the height so scenes scale with resolution.
/// </summary>
public sealed class LandscapeKit
{
    public LandscapeKit(SKSurface surface, double w, double h)
    {
        Surface = surface;
        W = w;
        H = h;
        C = surface.Canvas;
        C.Clear(SKColors.Transparent);
        C.Translate(0, (float)h);
        C.Scale(1, -1);
    }

    public SKSurface Surface { get; }
    public SKCanvas C { get; }
    public double W { get; }
    public double H { get; }
    public double U => H / 1000;
    public double Px(double units) => units * U;
    public double Fx(double fraction) => fraction * W;

    // ---- Sky & light ----

    /// <summary>Vertical gradient; positions are fractions of the height from the bottom.</summary>
    public void Sky(params (double Pos, uint Color)[] stops) =>
        C.FillLinear(stops.Select(s => Hex(s.Color)).ToArray(), stops.Select(s => (float)s.Pos).ToArray(), P(0, 0), P(0, H));

    public void Glow(double x, double y, double radius, uint color, double alpha, SKBlendMode blend = SKBlendMode.Screen)
    {
        using var shader = SKShader.CreateRadialGradient(P(x, y), (float)radius,
            new[] { Hex(color, alpha), Hex(color, alpha * 0.35), Hex(color, 0) }, new[] { 0f, 0.35f, 1f }, SKShaderTileMode.Decal);
        using var p = new SKPaint { Shader = shader, BlendMode = blend, IsAntialias = true };
        C.DrawCircle(P(x, y), (float)radius, p);
    }

    public void Stars(SeededGenerator rng, int count, double minY, double maxR = 1.3, uint tint = 0xFFFFFF)
    {
        for (int i = 0; i < count; i++)
        {
            double x = rng.Unit() * W;
            double y = (minY + (1 - minY) * Math.Pow(rng.Unit(), 0.8)) * H;
            double r = Px(rng.Range(0.25, maxR)) * (rng.Unit() < 0.06 ? 1.8 : 1);
            double a = rng.Range(0.35, 1);
            C.Circle(x, y, r, Hex(tint, a));
            if (r > Px(maxR) * 0.9)
            {
                Glow(x, y, r * 6, tint, 0.35);
                using var s = new SKPath();
                s.M(x - r * 5, y); s.L(x + r * 5, y);
                s.M(x, y - r * 5); s.L(x, y + r * 5);
                C.Stroke(s, Hex(tint, 0.35), Math.Max(0.6, r * 0.35));
            }
        }
    }

    public void Moon(double x, double y, double r, uint color = 0xFFF6DD, uint glowColor = 0xBFD3FF)
    {
        Glow(x, y, r * 7, glowColor, 0.28);
        Glow(x, y, r * 2.6, color, 0.35);
        using var disc = CirclePath(x, y, r);
        C.Fill(disc, Hex(color));
        C.Clipped(disc, () =>
        {
            C.FillRadial(new[] { Hex(0xFFFFFF, 0), Hex(0xD9CFB0, 0.45) }, new[] { 0.5f, 1f }, P(x, y), (float)r, P(x - r * 0.25, y + r * 0.25));
            var rng = new SeededGenerator(99);
            for (int i = 0; i < 7; i++)
            {
                double cx = x + rng.Range(-0.6, 0.6) * r, cy = y + rng.Range(-0.6, 0.6) * r;
                C.Circle(cx, cy, r * rng.Range(0.06, 0.2), Hex(0xCFC5A4, 0.35));
            }
        });
    }

    public void Sun(double x, double y, double r, uint core, uint halo, double haloRadius)
    {
        Glow(x, y, haloRadius, halo, 0.55);
        Glow(x, y, r * 3, core, 0.7);
        C.Circle(x, y, r, Hex(core));
    }

    /// <summary>Soft horizontal haze band centred at y (units).</summary>
    public void Fog(double y, double height, uint color, double alpha)
    {
        double y0 = Px(y - height / 2), y1 = Px(y + height / 2);
        C.Clipped(SKRect.Create(0, (float)y0, (float)W, (float)(y1 - y0)), () =>
            C.FillLinear(new[] { Hex(color, 0), Hex(color, alpha), Hex(color, 0) }, new[] { 0f, 0.5f, 1f }, P(0, y0), P(0, y1)));
    }

    // ---- Layers ----

    /// <summary>Draws into a reduced-size layer, blurs it and composites it over the canvas.</summary>
    public void BlurLayer(double scale, double radius, Action<SKCanvas> draw, SKBlendMode blend = SKBlendMode.SrcOver, double alpha = 1)
    {
        int lw = Math.Max(4, (int)(W * scale)), lh = Math.Max(4, (int)(H * scale));
        using var layer = NewSurface(lw, lh);
        var lc = layer.Canvas;
        lc.Clear(SKColors.Transparent);
        lc.Translate(0, lh);
        lc.Scale((float)(lw / W), (float)(-lh / H));
        draw(lc);
        lc.Flush();
        using var image = layer.Snapshot();
        SKImage final = image;
        SKImage? blurred = null;
        if (radius > 0)
        {
            using var bs = NewSurface(lw, lh);
            bs.Canvas.Clear(SKColors.Transparent);
            float sigma = (float)(radius * scale);
            using var filter = SKImageFilter.CreateBlur(sigma, sigma, SKShaderTileMode.Clamp);
            using var bp = new SKPaint { ImageFilter = filter };
            bs.Canvas.DrawImage(image, 0, 0, bp);
            bs.Canvas.Flush();
            blurred = bs.Snapshot();
            final = blurred;
        }
        using var p = new SKPaint
        {
            BlendMode = blend, Color = SKColors.White.WithAlpha((byte)Math.Round(Math.Clamp(alpha, 0, 1) * 255)),
            FilterQuality = SKFilterQuality.High, IsAntialias = true,
        };
        C.DrawUpright(final, SKRect.Create(0, 0, (float)W, (float)H), p);
        blurred?.Dispose();
    }

    private static readonly Lazy<SKImage> GrainTile = new(() =>
    {
        const int n = 256;
        var rng = new SeededGenerator(4242);
        var pixels = new SKColor[n * n];
        for (int i = 0; i < pixels.Length; i++)
        {
            byte v = (byte)Math.Clamp(128 + (int)((rng.Unit() - 0.5) * 200), 0, 255);
            pixels[i] = new SKColor(v, v, v, 255);
        }
        var bmp = new SKBitmap(n, n, SKColorType.Bgra8888, SKAlphaType.Premul) { Pixels = pixels };
        return SKImage.FromBitmap(bmp);
    });

    /// <summary>Fine film grain so large gradients never band.</summary>
    public void Grain(double amount = 0.07)
    {
        using var shader = SKShader.CreateImage(GrainTile.Value, SKShaderTileMode.Repeat, SKShaderTileMode.Repeat);
        using var p = new SKPaint { Shader = shader, BlendMode = SKBlendMode.Overlay, Color = SKColors.White.WithAlpha((byte)(amount * 255)) };
        C.DrawPaint(p);
    }

    // ---- Terrain ----

    /// <summary>Mountain ridge by midpoint displacement plus explicit peaks. Heights in units.</summary>
    public List<SKPoint> RidgePoints(SeededGenerator rng, double baseY, double amp, double rough = 0.55,
                                     params (double X, double Height, double Width)[] peaks)
    {
        const int count = 513;
        var hs = new double[count];
        hs[0] = rng.Range(-0.5, 0.5) * amp;
        hs[count - 1] = rng.Range(-0.5, 0.5) * amp;
        int step = count - 1;
        double a = amp;
        while (step > 1)
        {
            int half = step / 2;
            for (int i = half; i < count; i += step) hs[i] = (hs[i - half] + hs[i + half]) / 2 + rng.Range(-1, 1) * a;
            a *= rough;
            step = half;
        }
        var fine = new double[count];
        step = count - 1;
        a = 1;
        while (step > 1)
        {
            int half = step / 2;
            for (int i = half; i < count; i += step) fine[i] = (fine[i - half] + fine[i + half]) / 2 + rng.Range(-1, 1) * a;
            a *= 0.68;
            step = half;
        }
        var pts = new List<SKPoint>(count);
        for (int i = 0; i < count; i++)
        {
            double fx = (double)i / (count - 1);
            double lift = 0;
            foreach (var p in peaks)
            {
                double d = Math.Abs(fx - p.X) / p.Width;
                if (d < 1) lift += p.Height * Math.Pow(1 - d, 1.25);
            }
            double y = baseY + hs[i] + lift * (1 + 0.16 * fine[i]);
            pts.Add(P(fx * W, Px(y)));
        }
        return pts;
    }

    public static SKPath AreaPath(IReadOnlyList<SKPoint> pts, float bottom = 0)
    {
        var p = new SKPath();
        p.MoveTo(pts[0].X, bottom);
        foreach (var pt in pts) p.LineTo(pt);
        p.LineTo(pts[^1].X, bottom);
        p.Close();
        return p;
    }

    /// <summary>Fills a mountain range with rock gradient, optional snow caps and shaded left faces.</summary>
    public void Mountains(List<SKPoint> pts, uint top, uint bottom, uint? snow, double snowLine, SeededGenerator rng,
                          uint shade = 0x0A1430, double shadeAlpha = 0.28)
    {
        using var path = AreaPath(pts);
        float maxY = pts.Max(p => p.Y);
        C.Clipped(path, () =>
        {
            C.FillLinear(new[] { Hex(bottom), Hex(top) }, null, P(0, 0), P(0, maxY));
            if (snow is uint snowColor)
            {
                using var line = new SKPath();
                double y = Px(snowLine);
                line.M(0, H);
                line.L(0, y);
                double x = 0;
                while (x < W)
                {
                    x += W / 160;
                    y += Px(rng.Range(-6, 6));
                    y = Math.Max(Px(snowLine - 30), Math.Min(Px(snowLine + 30), y));
                    line.L(x, y);
                }
                line.L(W, H);
                line.Close();
                C.Clipped(line, () => C.FillLinear(new[] { Hex(snowColor, 0.85), Hex(snowColor) }, null, P(0, Px(snowLine)), P(0, maxY)));
            }
            int n = pts.Count;
            int i = 8;
            while (i < n - 8)
            {
                float windowMax = float.MinValue;
                for (int k = Math.Max(0, i - 24); k <= Math.Min(n - 1, i + 24); k++) windowMax = Math.Max(windowMax, pts[k].Y);
                if (pts[i].Y >= windowMax && pts[i].Y > Px(snowLine) * 0.5)
                {
                    int j = i;
                    while (j > 0 && pts[j - 1].Y <= pts[j].Y + Px(0.5)) j--;
                    var peak = pts[i];
                    var valley = pts[j];
                    double rise = peak.Y - valley.Y;
                    if (rise > Px(12))
                    {
                        var foot = P(peak.X + rise * 0.16, valley.Y - rise * 0.22);
                        using var face = new SKPath();
                        face.MoveTo(peak);
                        for (int k = i; k >= j; k--) face.LineTo(pts[k]);
                        face.LineTo(foot);
                        face.Close();
                        C.Clipped(face, () => C.FillLinear(new[] { Hex(shade, 0), Hex(shade, shadeAlpha * 0.7), Hex(shade, shadeAlpha) },
                                                           new[] { 0f, 0.35f, 1f }, P(0, foot.Y), P(0, peak.Y)));
                    }
                    i += 24;
                }
                i++;
            }
        });
    }

    /// <summary>Rolling hills: y = base + Σ a·sin(2π f x + p) (units). Optional bright rim along the crest.</summary>
    public void Hills(double baseY, (double A, double F, double P)[] waves, uint top, uint bottom, uint? rim = null, double rimWidth = 3)
    {
        var pts = new List<SKPoint>();
        const int steps = 200;
        for (int i = 0; i <= steps; i++)
        {
            double fx = (double)i / steps;
            double y = baseY;
            foreach (var w in waves) y += w.A * Math.Sin(2 * Math.PI * w.F * fx + w.P);
            pts.Add(P(fx * W, Px(y)));
        }
        using var path = AreaPath(pts);
        float maxY = pts.Max(p => p.Y);
        C.Clipped(path, () => C.FillLinear(new[] { Hex(bottom), Hex(top) }, null, P(0, 0), P(0, maxY)));
        if (rim is uint rimColor)
        {
            using var crest = new SKPath();
            crest.MoveTo(pts[0]);
            foreach (var p in pts.Skip(1)) crest.LineTo(p);
            C.Clipped(path, () => C.Stroke(crest, Hex(rimColor, 0.9), Px(rimWidth)));
        }
    }

    /// <summary>Pixel height of a hill curve at x, matching <see cref="Hills"/>.</summary>
    public double HillY(double baseY, (double A, double F, double P)[] waves, double x)
    {
        double y = baseY, fx = x / W;
        foreach (var w in waves) y += w.A * Math.Sin(2 * Math.PI * w.F * fx + w.P);
        return Px(y);
    }

    // ---- Trees ----

    /// <summary>Stylised conifer with optional snow on each tier.</summary>
    public void Pine(double x, double baseY, double height, SKColor color, SKColor? snow, double lean = 0)
    {
        const int tiers = 5;
        double trunkH = height * 0.08;
        C.Rect(x - height * 0.025, baseY, height * 0.05, trunkH + height * 0.05, Mix(color, Hex(0x000000), 0.25));
        double body = height - trunkH;
        for (int i = 0; i < tiers; i++)
        {
            double t = (double)i / tiers;
            double bottomY = baseY + trunkH + body * t * 0.78;
            double apexY = Math.Min(baseY + height, bottomY + body * (0.4 - t * 0.12));
            double half = height * 0.34 * (1 - t * 0.74);
            double cx = x + lean * (bottomY - baseY);
            double ax = x + lean * (apexY - baseY);
            using var tier = new SKPath();
            tier.M(cx - half, bottomY);
            tier.L(ax, apexY);
            tier.L(cx + half, bottomY);
            tier.Q(cx, bottomY + half * 0.22, cx - half, bottomY);
            tier.Close();
            C.Fill(tier, color);
            if (snow is SKColor s)
            {
                double capY = apexY - (apexY - bottomY) * 0.55;
                double capHalf = half * 0.52;
                using var cap = new SKPath();
                cap.M(ax - capHalf * 1.05, capY);
                cap.L(ax, apexY);
                cap.L(ax + capHalf * 1.05, capY);
                cap.Q(ax + capHalf * 0.6, capY - (apexY - capY) * 0.25, ax + capHalf * 0.2, capY + (apexY - capY) * 0.12);
                cap.Q(ax - capHalf * 0.5, capY - (apexY - capY) * 0.3, ax - capHalf * 1.05, capY);
                cap.Close();
                C.Fill(cap, s);
                using var l = Ellipse(cx - half * 0.86, bottomY + half * 0.05, half * 0.2, half * 0.08);
                C.Fill(l, s);
                using var r = Ellipse(cx + half * 0.86, bottomY + half * 0.05, half * 0.2, half * 0.08);
                C.Fill(r, s);
            }
        }
    }

    /// <summary>A band of trees; base and height ranges in units, x in fractions.</summary>
    public void Forest(SeededGenerator rng, int count, (double Lo, double Hi) x, (double Lo, double Hi) baseRange, (double Lo, double Hi) height,
                       uint color, uint? snow, double snowAlpha = 1, Func<double, double>? baseCurve = null)
    {
        var trees = new List<(double X, double B, double H)>();
        for (int i = 0; i < count; i++)
        {
            double tx = rng.Range(x.Lo, x.Hi) * W;
            double b = baseCurve?.Invoke(tx) ?? Px(rng.Range(baseRange.Lo, baseRange.Hi));
            trees.Add((tx, b + Px(rng.Range(-3, 3)), Px(rng.Range(height.Lo, height.Hi))));
        }
        foreach (var t in trees.OrderByDescending(t => t.B))
            Pine(t.X, t.B, t.H, Hex(color), snow is uint s ? Hex(s, snowAlpha) : null);
    }

    public void Birch(double x, double baseY, double top, double bw, SeededGenerator rng, uint bark = 0xF3F0EA, uint mark = 0x2A2623, double alpha = 1)
    {
        double lean = rng.Range(-0.015, 0.015) * (top - baseY);
        using var trunk = new SKPath();
        trunk.M(x - bw / 2, baseY);
        trunk.L(x - bw * 0.32 + lean, top);
        trunk.L(x + bw * 0.32 + lean, top);
        trunk.L(x + bw / 2, baseY);
        trunk.Close();
        using var layerPaint = new SKPaint { Color = SKColors.White.WithAlpha((byte)Math.Round(alpha * 255)) };
        C.SaveLayer(layerPaint);
        C.Clipped(trunk, () =>
        {
            C.FillLinear(new[] { Hex(bark), Hex(bark), Mix(Hex(bark), Hex(0x8A8478), 0.45) }, new[] { 0f, 0.55f, 1f },
                         P(x - bw / 2, 0), P(x + bw / 2, 0));
            double y = baseY + bw * 0.5;
            while (y < top)
            {
                double len = bw * rng.Range(0.25, 0.85);
                double off = rng.Range(-0.5, 0.5) * (bw - len);
                double tall = bw * rng.Range(0.05, 0.13);
                double shift = lean * (y - baseY) / (top - baseY);
                using var e = Ellipse(x + off + shift, y, len / 2, tall / 2);
                C.Fill(e, Hex(mark, 0.85));
                y += bw * rng.Range(0.35, 1.2);
            }
        });
        if (bw > Px(20) && alpha >= 1)
        {
            for (int i = 0; i < 3; i++)
            {
                double sy = baseY + (top - baseY) * rng.Range(0.5, 0.9);
                double dir = rng.Unit() < 0.5 ? -1 : 1;
                double sx = x + lean * (sy - baseY) / (top - baseY) + dir * bw * 0.3;
                double tipX = sx + dir * bw * rng.Range(1.0, 2.2), tipY = sy + bw * rng.Range(0.8, 1.8);
                using var b = new SKPath();
                b.M(sx, sy);
                b.Q(sx + dir * bw * 0.8, sy + bw * 0.2, tipX, tipY);
                C.Stroke(b, Hex(0x4E463E, 0.85), Math.Max(1, bw * 0.07));
                using var b2 = Line((sx + tipX) / 2, (sy + tipY) / 2, tipX + dir * bw * 0.3, tipY + bw * 0.6);
                C.Stroke(b2, Hex(0x4E463E, 0.7), Math.Max(0.7, bw * 0.035));
            }
        }
        C.Restore();
    }

    // ---- Buildings ----

    public List<SKPoint> House(double x, double baseY, double hw, uint wall, uint roof, int windows, bool lit, bool chimney, SeededGenerator rng)
    {
        double wallH = hw * 0.62;
        var body = SKRect.Create((float)(x - hw / 2), (float)baseY, (float)hw, (float)wallH);
        C.Rect(body.Left, body.Top, body.Width, body.Height, Hex(wall));
        C.Clipped(body, () =>
        {
            C.FillLinear(new[] { Hex(0x000000, 0.25), Hex(0x000000, 0) }, null, P(x + hw / 2, 0), P(x - hw * 0.1, 0));
            for (int k = 1; k < 6; k++)
            {
                double ly = baseY + wallH * k / 6;
                using var l = Line(x - hw / 2, ly, x + hw / 2, ly);
                C.Stroke(l, Hex(0x000000, 0.12), Math.Max(1, hw * 0.01));
            }
        });
        double peakX = x, peakY = baseY + wallH + hw * 0.42;
        if (chimney)
        {
            C.Rect(x + hw * 0.18, baseY + wallH + hw * 0.12, hw * 0.1, hw * 0.32, Hex(0x6B4A3A));
            using var cap = Ellipse(x + hw * 0.23, baseY + wallH + hw * 0.44, hw * 0.075, hw * 0.03);
            C.Fill(cap, Hex(0xF4F8FF));
        }
        using var roofPath = new SKPath();
        roofPath.M(x - hw * 0.62, baseY + wallH - hw * 0.02);
        roofPath.L(peakX, peakY);
        roofPath.L(x + hw * 0.62, baseY + wallH - hw * 0.02);
        roofPath.Close();
        C.Fill(roofPath, Hex(roof));
        using var snow = new SKPath();
        double t = hw * 0.09;
        double eave = baseY + wallH - hw * 0.01;
        snow.M(x - hw * 0.66, eave);
        snow.L(peakX, peakY + t * 0.9);
        snow.L(x + hw * 0.66, eave);
        double sx = x + hw * 0.66;
        bool drip = false;
        while (sx > x - hw * 0.66)
        {
            double nx = sx - hw * rng.Range(0.06, 0.12);
            snow.Q((sx + nx) / 2, eave - t * (drip ? 0.9 : 0.35), Math.Max(x - hw * 0.66, nx), eave - (drip ? t * 0.55 : t * 0.15));
            drip = !drip;
            sx = nx;
        }
        snow.Close();
        C.Fill(snow, Hex(0xF6F9FF));
        C.Clipped(snow, () => C.FillLinear(new[] { Hex(0xB9CBE6, 0.9), Hex(0xFFFFFF, 0) }, null, P(0, baseY + wallH - t), P(0, baseY + wallH + hw * 0.2)));
        var centers = new List<SKPoint>();
        double ww = hw * 0.16, wh = hw * 0.15;
        for (int k = 0; k < windows; k++)
        {
            double fx = windows == 1 ? 0 : ((double)k / (windows - 1) - 0.5) * hw * 0.5;
            double cx = x + fx, cy = baseY + wallH * 0.52;
            var r = SKRect.Create((float)(cx - ww / 2), (float)(cy - wh / 2), (float)ww, (float)wh);
            float inset = (float)(hw * 0.015);
            C.Rect(r.Left - inset, r.Top - inset, r.Width + 2 * inset, r.Height + 2 * inset, Hex(0x2B1D16));
            if (lit) C.Clipped(r, () => C.FillLinear(new[] { Hex(0xFFE7A3), Hex(0xFFB347) }, null, P(0, r.Bottom), P(0, r.Top)));
            else C.Rect(r.Left, r.Top, r.Width, r.Height, Hex(0x2A3550));
            using var bars = new SKPath();
            bars.M(cx, r.Top); bars.L(cx, r.Bottom);
            bars.M(r.Left, cy); bars.L(r.Right, cy);
            C.Stroke(bars, Hex(0x2B1D16), Math.Max(1, hw * 0.012));
            centers.Add(P(cx, cy));
        }
        return centers;
    }

    /// <summary>Deer silhouette standing at foot; size is the body length in pixels.</summary>
    public void Deer(double fx, double fy, double s, uint color, bool facingLeft = true)
    {
        C.Save();
        C.Translate((float)fx, (float)fy);
        if (facingLeft) C.Scale(-1, 1);
        var c = Hex(color);
        using (var body = Ellipse(0, s * 0.62, s * 0.42, s * 0.17)) C.Fill(body, c);
        foreach (var (lx, lean) in new[] { (-0.3, -0.03), (-0.2, 0.02), (0.22, -0.02), (0.32, 0.03) })
        {
            using var leg = Line(s * lx, s * 0.58, s * (lx + lean), 0);
            C.Stroke(leg, c, s * 0.05);
        }
        using (var neck = new SKPath())
        {
            neck.M(s * 0.28, s * 0.68);
            neck.Q(s * 0.42, s * 0.78, s * 0.46, s * 1.02);
            C.Stroke(neck, c, s * 0.13);
        }
        using (var head = Ellipse(s * 0.53, s * 1.04, s * 0.12, s * 0.065)) C.Fill(head, c);
        using (var ear = Ellipse(s * 0.42, s * 1.1, s * 0.03, s * 0.06)) C.Fill(ear, c);
        using var antlers = new SKPath();
        antlers.M(s * 0.47, s * 1.09); antlers.Q(s * 0.36, s * 1.22, s * 0.36, s * 1.45);
        antlers.M(s * 0.39, s * 1.26); antlers.L(s * 0.27, s * 1.36);
        antlers.M(s * 0.37, s * 1.37); antlers.L(s * 0.47, s * 1.5);
        antlers.M(s * 0.51, s * 1.09); antlers.Q(s * 0.62, s * 1.2, s * 0.6, s * 1.42);
        antlers.M(s * 0.59, s * 1.25); antlers.L(s * 0.7, s * 1.33);
        C.Stroke(antlers, c, s * 0.025);
        C.Restore();
    }

    // ---- Snowfall ----

    /// <summary>Static falling snow; with blur the flakes look like out-of-focus bokeh.</summary>
    public void Snowfall(SeededGenerator rng, int count, (double Lo, double Hi) size, (double Lo, double Hi) alpha, double blur = 0)
    {
        void Paint(SKCanvas c)
        {
            for (int i = 0; i < count; i++)
            {
                double x = rng.Unit() * W, y = rng.Unit() * H;
                double r = Px(rng.Range(size.Lo, size.Hi));
                c.FillRadial(new[] { Hex(0xFFFFFF, rng.Range(alpha.Lo, alpha.Hi)), Hex(0xFFFFFF, 0) }, new[] { 0.5f, 1f }, P(x, y), (float)r, extend: false);
            }
        }
        if (blur > 0) BlurLayer(0.5, Px(blur), Paint);
        else Paint(C);
    }

    /// <summary>Glittering specks on a snow field.</summary>
    public void Sparkles(SeededGenerator rng, int count, double yMax, uint color = 0xFFFFFF)
    {
        for (int i = 0; i < count; i++)
        {
            double x = rng.Unit() * W, y = rng.Unit() * Px(yMax);
            C.Circle(x, y, Px(rng.Range(0.3, 1.0)), Hex(color, rng.Range(0.3, 0.9)));
        }
    }
}
