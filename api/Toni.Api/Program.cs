using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.IdentityModel.Tokens;
using Toni.Api;
using Toni.Api.Auth;
using Toni.Api.Data;
using Toni.Api.Endpoints;
using Toni.Api.Hubs;

var builder = WebApplication.CreateBuilder(args);

var toni = builder.Configuration.GetSection("Toni").Get<ToniOptions>() ?? new ToniOptions();
if (toni.JwtKey.Length < 32)
    throw new InvalidOperationException("Toni:JwtKey muss mindestens 32 Zeichen lang sein.");

builder.Services.Configure<ToniOptions>(builder.Configuration.GetSection("Toni"));
// SQLite is a zero-setup option for local development; production runs on Postgres with migrations.
var useSqlite = builder.Configuration.GetConnectionString("Default")?.StartsWith("Data Source=", StringComparison.OrdinalIgnoreCase) == true;
builder.Services.AddDbContext<ToniDb>(o =>
{
    if (useSqlite) o.UseSqlite(builder.Configuration.GetConnectionString("Default"));
    else o.UseNpgsql(builder.Configuration.GetConnectionString("Default"));
});
builder.Services.AddSingleton<IPasswordHasher<User>, PasswordHasher<User>>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddScoped<Seeder>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = TokenService.Issuer,
            ValidAudience = TokenService.Issuer,
            IssuerSigningKey = TokenService.SigningKey(toni.JwtKey),
            NameClaimType = "sub",
            RoleClaimType = "role",
        };
        o.Events = new JwtBearerEvents { OnTokenValidated = CurrentUser.OnTokenValidated };
    });
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("admin", p => p.RequireRole(Roles.Admin));

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy("login", http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "?",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
});

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    if (builder.Environment.IsDevelopment()) p.SetIsOriginAllowed(_ => true);
    else p.WithOrigins(toni.CorsOrigins);
    p.AllowAnyHeader().AllowAnyMethod().AllowCredentials();
}));

builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    // Behind the cluster ingress; the proxy address is not known in advance.
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownIPNetworks.Clear();
    o.KnownProxies.Clear();
});

builder.Services.AddSignalR();
builder.Services.AddHealthChecks().AddDbContextCheck<ToniDb>(tags: ["ready"]);

var app = builder.Build();

app.UseForwardedHeaders();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

var api = app.MapGroup("/api");
api.MapPublic();
api.MapGroup("").RequireAuthorization().BroadcastChanges().MapMember();
api.MapGroup("").RequireAuthorization("admin").BroadcastChanges().MapAdmin();

app.MapHub<StateHub>(StateHub.Path);
app.MapHealthChecks("/healthz", new() { Predicate = _ => false });
app.MapHealthChecks("/readyz", new() { Predicate = c => c.Tags.Contains("ready") });

if (!app.Environment.IsEnvironment("Testing"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<ToniDb>().Database;
    if (useSqlite) await db.EnsureCreatedAsync();
    else await db.MigrateAsync();
    await scope.ServiceProvider.GetRequiredService<Seeder>().RunAsync();
}

app.Run();

public partial class Program;
