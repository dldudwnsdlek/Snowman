namespace Snowman.Checks;

internal static class Harness
{
    private static int _count;
    private static readonly List<string> Failures = new();

    public static void Check(string name, bool ok, string detail = "")
    {
        _count++;
        if (!ok) Failures.Add($"FAIL {name} {detail}");
    }

    public static void Close(string name, double a, double b, double tol) =>
        Check(name, Math.Abs(a - b) <= tol, $"got {a}, expected {b} ± {tol}");

    public static int Finish()
    {
        if (Failures.Count == 0)
        {
            Console.WriteLine($"All {_count} checks passed");
            return 0;
        }
        foreach (var f in Failures) Console.WriteLine(f);
        Console.WriteLine($"{Failures.Count} of {_count} checks failed");
        return 1;
    }
}
