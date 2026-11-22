using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Media;
using Snowman.Core;

namespace Snowman.App.Scene;

/// <summary>Keeps a cached, frozen outline of the snow on one ledge and draws it.</summary>
internal sealed class PileRenderer
{
    /// <summary>Snow overlaps the ledge line by this much so it sits on the window edge.</summary>
    public const double BaseInset = 2;

    private static readonly Pen RidgePen = SpriteDraw.FrozenPen(Color.FromArgb(140, 0x9F, 0xB5, 0xD3), 0.9);
    private static readonly Pen ShinePen = SpriteDraw.FrozenPen(Color.FromArgb(230, 255, 255, 255), 0.9);
    private static readonly TranslateTransform ShineShift = Freeze(new TranslateTransform(0, -1.1));

    private double _lastBuild = -1;
    private StreamGeometry? _body;
    private StreamGeometry? _ridge;
    private LinearGradientBrush? _brush;
    private double _brushHeight = -1;

    public bool Dirty { get; set; } = true;

    private static TranslateTransform Freeze(TranslateTransform t)
    {
        t.Freeze();
        return t;
    }

    public void Rebuild(SnowPile pile, Visibility vis, double now, bool force = false)
    {
        if (!Dirty || (!force && now - _lastBuild < 1.0 / 20)) return;
        Dirty = false;
        _lastBuild = now;
        int n = pile.ColumnCount;
        var tops = new double[n];
        double maxVisible = 0;
        for (int c = 0; c < n; c++)
        {
            double v = vis.VisibleHeight(c, pile.Heights[c]);
            tops[c] = v;
            if (v > maxVisible) maxVisible = v;
        }
        if (maxVisible <= 0.3)
        {
            _body = null;
            _ridge = null;
            return;
        }
        var body = new StreamGeometry();
        var ridge = new StreamGeometry();
        using (var bc = body.Open())
        using (var rc = ridge.Open())
        {
            int c = 0;
            var pts = new List<Point>();
            while (c < n)
            {
                if (tops[c] <= 0.3) { c++; continue; }
                pts.Clear();
                while (c < n && tops[c] > 0.3)
                {
                    pts.Add(new Point(pile.CenterX(c), BaseInset + tops[c]));
                    c++;
                }
                double left = Math.Max(0, pts[0].X - SnowPile.ColumnWidth / 2);
                double right = Math.Min(pile.Width, pts[^1].X + SnowPile.ColumnWidth / 2);
                var start = new Point(left, pts[0].Y * 0.75);
                var end = new Point(right, pts[^1].Y * 0.75);
                bc.BeginFigure(new Point(left, 0), true, true);
                bc.LineTo(start, false, false);
                rc.BeginFigure(start, false, false);
                for (int k = 0; k < pts.Count; k++)
                {
                    var next = k + 1 < pts.Count ? pts[k + 1] : end;
                    var mid = new Point((pts[k].X + next.X) / 2, (pts[k].Y + next.Y) / 2);
                    bc.QuadraticBezierTo(pts[k], mid, false, false);
                    rc.QuadraticBezierTo(pts[k], mid, true, false);
                }
                bc.LineTo(end, false, false);
                rc.LineTo(end, true, false);
                bc.LineTo(new Point(right, 0), false, false);
            }
        }
        body.Freeze();
        ridge.Freeze();
        _body = body;
        _ridge = ridge;
        double brushHeight = Math.Ceiling(maxVisible + BaseInset + 2);
        if (_brush is null || Math.Abs(brushHeight - _brushHeight) > 1.5)
        {
            var b = new LinearGradientBrush
            {
                MappingMode = BrushMappingMode.Absolute,
                StartPoint = new Point(0, 0),
                EndPoint = new Point(0, brushHeight),
            };
            b.GradientStops.Add(new GradientStop(Color.FromRgb(0xD2, 0xDE, 0xEE), 0));
            b.GradientStops.Add(new GradientStop(Color.FromRgb(0xEE, 0xF4, 0xFB), 0.45));
            b.GradientStops.Add(new GradientStop(Colors.White, 1));
            b.Freeze();
            _brush = b;
            _brushHeight = brushHeight;
        }
    }

    public void Draw(DrawingContext dc, LedgeSpec spec)
    {
        if (_body is null || _ridge is null) return;
        dc.PushTransform(new TranslateTransform(spec.X0, spec.Y - BaseInset));
        dc.DrawGeometry(_brush, null, _body);
        dc.DrawGeometry(null, RidgePen, _ridge);
        dc.PushTransform(ShineShift);
        dc.DrawGeometry(null, ShinePen, _ridge);
        dc.Pop();
        dc.Pop();
    }
}
