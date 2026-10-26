using System.Text.RegularExpressions;

namespace Toni.Api.Data;

public static partial class Palette
{
    public static readonly string[] Colors =
        ["#a3e635", "#f59e0b", "#f472b6", "#38bdf8", "#c084fc", "#fb7185", "#34d399", "#fbbf24"];

    public static string ForIndex(int i) => Colors[i % Colors.Length];

    public static bool IsHexColor(string? s) => s is not null && HexColor().IsMatch(s);

    [GeneratedRegex("^#[0-9a-fA-F]{6}$")]
    private static partial Regex HexColor();
}
