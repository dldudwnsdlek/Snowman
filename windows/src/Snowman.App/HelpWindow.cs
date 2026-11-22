using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Snowman.Art;
using Snowman.Core;

namespace Snowman.App;

/// <summary>"사용법" window.</summary>
internal static class HelpWindow
{
    private static Window? _window;

    private static readonly (string Icon, string Heading, string Body)[] Sections =
    {
        ("❄", "눈이 내려요", "모든 창 위, 작업 표시줄 위, 화면 맨 아래에 눈이 쌓여요. 알림 영역의 ❄ 아이콘에서 눈 양(조금·보통·펑펑)을 고르거나 잠시 멈출 수 있어요."),
        ("🪟", "창을 닫으면 우수수", "눈이 쌓인 창을 닫거나 최소화하면 쌓였던 눈이 떨어져 아래에 다시 쌓여요. 창을 세게 흔들어도 눈이 털려요."),
        ("🧤", "눈 굴리기", "쌓인 눈 위에 마우스를 올리면 장갑이 나타나요. 눌러서 한 줌 뜬 뒤 옆으로 끌면 굴러가며 커져요. 위로 들어 올리면 들고 다닐 수 있어요."),
        ("⛄", "눈사람 만들기", "눈덩이를 다른 눈덩이 위에 놓으면 팔, 눈, 코, 모자가 하나씩 생기며 눈사람이 완성돼요. 메뉴에서 5종 중 하나를 바로 만들 수도 있어요."),
        ("👋", "살아 있는 눈사람", "눈사람은 숨 쉬고, 눈을 깜빡이고, 커서가 다가오면 손을 흔들어요. 한 번 클릭하면 춤을 춰요."),
        ("↗", "던지기", "눈사람을 잡고 휙 던지면 화면 가장자리에 부딪혀 와장창! 반대로 튕겨요. 아주 세게 던지면 부서져서 눈덩이 두 개로 돌아가요."),
        ("🚜", "제설차 부르기", "제설차가 작업 표시줄 위 눈을 싹 밀어내요. 작업 표시줄이 숨어 있으면 화면 아래쪽 눈을 치워요."),
    };

    public static void ShowHelp()
    {
        if (_window is null)
        {
            _window = Build();
            _window.Closed += (_, _) => _window = null;
        }
        _window.Show();
        _window.Activate();
    }

    public static Window? Current => _window;

    private static Window Build()
    {
        var root = new StackPanel { Margin = new Thickness(28, 22, 28, 24) };
        var header = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 12) };
        foreach (var style in SnowmanStyleInfo.All)
        {
            using var img = SnowmanArt.Composite(style, 64, 2);
            var bmp = Sprites.ToBitmap(img);
            header.Children.Add(new Image { Source = bmp, Height = 64, Width = bmp.PixelWidth / 2.0, Margin = new Thickness(0, 0, 8, 0) });
        }
        root.Children.Add(header);
        root.Children.Add(new TextBlock
        {
            Text = "눈 내리는 윈도우, Snowman", FontSize = 22, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 14),
        });
        foreach (var (icon, heading, body) in Sections)
        {
            var row = new Grid { Margin = new Thickness(0, 0, 0, 12) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(34) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var glyph = new TextBlock { Text = icon, FontSize = 18, FontFamily = new FontFamily("Segoe UI Emoji"), VerticalAlignment = VerticalAlignment.Top };
            var text = new StackPanel();
            text.Children.Add(new TextBlock { Text = heading, FontSize = 14, FontWeight = FontWeights.SemiBold });
            text.Children.Add(new TextBlock
            {
                Text = body, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Color.FromRgb(0x55, 0x5B, 0x66)),
                Margin = new Thickness(0, 3, 0, 0),
            });
            Grid.SetColumn(glyph, 0);
            Grid.SetColumn(text, 1);
            row.Children.Add(glyph);
            row.Children.Add(text);
            root.Children.Add(row);
        }
        var window = new Window
        {
            Title = "Snowman 사용법",
            Content = root,
            Width = 540,
            SizeToContent = SizeToContent.Height,
            ResizeMode = ResizeMode.NoResize,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            Background = Brushes.White,
            FontFamily = new FontFamily("Malgun Gothic"),
            Topmost = true,
        };
        try
        {
            window.Icon = BitmapFrame.Create(new Uri("pack://application:,,,/Assets/Snowman.ico"));
        }
        catch (Exception e)
        {
            Program.Log("help icon failed: " + e.Message);
        }
        return window;
    }
}
