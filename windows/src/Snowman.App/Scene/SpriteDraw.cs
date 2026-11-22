using System;
using System.Windows;
using System.Windows.Media;

namespace Snowman.App.Scene;

/// <summary>
/// Matrix helpers. The scene is y-up (origin bottom-left); one flip is pushed for the whole scene,
/// so every sprite maps its image (v down) into y-up space with these matrices.
/// </summary>
internal static class SpriteDraw
{
    /// <summary>Image-local → parent space. Anchor is normalised from the bottom-left, rotation is counter-clockwise.</summary>
    public static Matrix Local(double w, double h, double ax, double ay, double sx, double sy, double rotation, double px, double py)
    {
        var m = new Matrix(1, 0, 0, -1, -ax * w, h * (1 - ay));
        m.Scale(sx, sy);
        if (rotation != 0) m.Rotate(rotation * 180 / Math.PI);
        m.Translate(px, py);
        return m;
    }

    public static Matrix Node(double sx, double sy, double rotation, double px, double py)
    {
        var m = Matrix.Identity;
        m.Scale(sx, sy);
        if (rotation != 0) m.Rotate(rotation * 180 / Math.PI);
        m.Translate(px, py);
        return m;
    }

    public static void Image(DrawingContext dc, ImageSource img, double w, double h, Matrix m, double opacity = 1)
    {
        if (opacity <= 0.001) return;
        dc.PushTransform(new MatrixTransform(m));
        bool fade = opacity < 0.999;
        if (fade) dc.PushOpacity(opacity);
        dc.DrawImage(img, new Rect(0, 0, w, h));
        if (fade) dc.Pop();
        dc.Pop();
    }

    public static Brush Frozen(Color c)
    {
        var b = new SolidColorBrush(c);
        b.Freeze();
        return b;
    }

    public static Pen FrozenPen(Color c, double thickness)
    {
        var p = new Pen(Frozen(c), thickness) { LineJoin = PenLineJoin.Round, StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round };
        p.Freeze();
        return p;
    }
}
