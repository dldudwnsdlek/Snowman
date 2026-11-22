using System;
using System.IO;
using System.Threading;
using System.Windows;

namespace Snowman.App;

internal static class Program
{
    public static string DataFolder { get; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Snowman");

    [STAThread]
    private static int Main()
    {
        using var mutex = new Mutex(true, @"Local\SnowmanDesktopSnow", out bool created);
        if (!created) return 0;
        Directory.CreateDirectory(DataFolder);
        System.Windows.Forms.Application.EnableVisualStyles();
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.DispatcherUnhandledException += (_, e) =>
        {
            Log("UI error: " + e.Exception);
            e.Handled = true;
        };
        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log("Fatal: " + e.ExceptionObject);
        var controller = new SnowController(app);
        app.Startup += (_, _) => controller.Start();
        app.Exit += (_, _) => controller.Stop();
        return app.Run();
    }

    public static void Log(string message)
    {
        try
        {
            File.AppendAllText(Path.Combine(DataFolder, "snowman.log"), $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {message}{Environment.NewLine}");
        }
        catch
        {
            // logging must never crash the app
        }
    }
}
