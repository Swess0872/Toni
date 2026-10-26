namespace Toni.Api;

public class ToniOptions
{
    /// <summary>HMAC key for signing session tokens, at least 32 characters.</summary>
    public string JwtKey { get; set; } = "";
    /// <summary>Sessions stay valid this long ("angemeldet bleiben").</summary>
    public int SessionDays { get; set; } = 90;
    /// <summary>
    /// Fills an empty database with the prototype's demo group and shows the
    /// demo-login chips in the login modal. Only for local/staging builds.
    /// </summary>
    public bool DemoMode { get; set; }
    /// <summary>First admin, created on startup when the database has no logins yet.</summary>
    public string? AdminUsername { get; set; }
    public string? AdminPassword { get; set; }
    public string? AdminName { get; set; }
    /// <summary>Extra origins allowed to call the API from a browser (e.g. flutter run -d chrome).</summary>
    public string[] CorsOrigins { get; set; } = [];
}
