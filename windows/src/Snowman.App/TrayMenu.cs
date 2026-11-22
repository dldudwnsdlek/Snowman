using System;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App;

/// <summary>The ❄ icon in the notification area and its menu (same items as the macOS menu bar version).</summary>
internal sealed class TrayMenu : IDisposable
{
    private readonly SnowController _c;
    private readonly NotifyIcon _icon;
    private readonly ContextMenuStrip _menu = new();
    private readonly Dictionary<SnowAmount, ToolStripMenuItem> _amountItems = new();
    private readonly ToolStripMenuItem _pause;
    private readonly ToolStripMenuItem _windows;
    private readonly ToolStripMenuItem _sound;

    public TrayMenu(SnowController controller)
    {
        _c = controller;
        _pause = Item("눈 멈추기", () => _c.SetSnowing(_c.Settings.Paused), "Ctrl+P");
        _menu.Items.Add(_pause);
        var amount = new ToolStripMenuItem("눈 양");
        foreach (var a in SnowAmountInfo.All)
        {
            var it = Item(a.Title(), () => _c.SetAmount(a));
            _amountItems[a] = it;
            amount.DropDownItems.Add(it);
        }
        _menu.Items.Add(amount);
        _windows = Item("창 위에도 쌓기", () => _c.SetAccumulateOnWindows(!_c.Settings.AccumulateOnWindows));
        _menu.Items.Add(_windows);
        _menu.Items.Add(new ToolStripSeparator());

        var snowman = new ToolStripMenuItem("눈사람 만들기 ⛄");
        foreach (var style in SnowmanStyleInfo.All)
        {
            var it = Item($"{style.Title()} 눈사람", () => _c.SpawnSnowman(style));
            using var img = SnowmanArt.Composite(style, 22, 1.5);
            it.Image = Sprites.ToGdi(img);
            it.ImageScaling = ToolStripItemImageScaling.None;
            snowman.DropDownItems.Add(it);
        }
        snowman.DropDownItems.Add(new ToolStripSeparator());
        snowman.DropDownItems.Add(Item("랜덤", () => _c.SpawnSnowman(null)));
        _menu.Items.Add(snowman);
        _menu.Items.Add(Item("제설차 부르기 🚜", _c.CallPlow, "Ctrl+R"));
        _menu.Items.Add(Item("쌓인 눈 치우기", _c.ClearSnow, "Ctrl+C"));
        _menu.Items.Add(Item("눈사람 모두 치우기", _c.ClearSnowmen));
        _menu.Items.Add(new ToolStripSeparator());

        _sound = Item("효과음", () => _c.SetSound(!_c.Settings.SoundOn));
        _menu.Items.Add(_sound);
        _menu.Items.Add(Item("사용법", HelpWindow.ShowHelp));
        _menu.Items.Add(Item("끝내기", _c.Quit, "Ctrl+Q"));

        _menu.Opening += (_, _) => Refresh();
        _menu.KeyDown += (_, e) =>
        {
            if (!e.Control) return;
            Action? action = e.KeyCode switch
            {
                Keys.P => () => _c.SetSnowing(_c.Settings.Paused),
                Keys.R => _c.CallPlow,
                Keys.C => _c.ClearSnow,
                Keys.Q => _c.Quit,
                _ => null,
            };
            if (action is null) return;
            _menu.Close();
            action();
        };

        using var trayImage = SpriteArt.TraySnowflake(32);
        using var bitmap = Sprites.ToGdi(trayImage);
        _icon = new NotifyIcon
        {
            Icon = Icon.FromHandle(bitmap.GetHicon()),
            Text = "Snowman — 눈 내리는 윈도우",
            ContextMenuStrip = _menu,
            Visible = true,
        };
        _icon.MouseUp += (_, e) =>
        {
            if (e.Button != MouseButtons.Left) return;
            typeof(NotifyIcon).GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic)?.Invoke(_icon, null);
        };
        Refresh();
    }

    private static ToolStripMenuItem Item(string text, Action action, string? shortcut = null)
    {
        var it = new ToolStripMenuItem(text);
        if (shortcut is not null) it.ShortcutKeyDisplayString = shortcut;
        it.Click += (_, _) =>
        {
            try
            {
                action();
            }
            catch (Exception e)
            {
                Program.Log("menu action failed: " + e);
            }
        };
        return it;
    }

    private void Refresh()
    {
        var s = _c.Settings;
        _pause.Text = s.Paused ? "눈 다시 내리기" : "눈 멈추기";
        foreach (var (a, it) in _amountItems) it.Checked = a == s.AmountValue;
        _windows.Checked = s.AccumulateOnWindows;
        _sound.Checked = s.SoundOn;
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
        _menu.Dispose();
    }
}
