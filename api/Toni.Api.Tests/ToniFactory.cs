using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Toni.Api.Contracts;
using Toni.Api.Data;

namespace Toni.Api.Tests;

/// <summary>Runs the real API against an in-memory SQLite database seeded with the demo group.</summary>
public class ToniFactory : WebApplicationFactory<Program>
{
    readonly SqliteConnection _connection = new("DataSource=:memory:");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        _connection.Open();
        builder.UseEnvironment("Testing");
        builder.UseSetting("Toni:JwtKey", "test-key-0123456789abcdef0123456789abcdef");
        builder.UseSetting("Toni:DemoMode", "true");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<ToniDb>>();
            services.RemoveAll<IDbContextOptionsConfiguration<ToniDb>>();
            services.AddDbContext<ToniDb>(o => o.UseSqlite(_connection));
        });
    }

    public async Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        await scope.ServiceProvider.GetRequiredService<ToniDb>().Database.EnsureCreatedAsync();
        await scope.ServiceProvider.GetRequiredService<Seeder>().RunAsync();
    }

    public async Task<HttpClient> LoginAsync(string username, string password)
    {
        var client = CreateClient();
        var res = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(username, password));
        res.EnsureSuccessStatusCode();
        var login = await res.Content.ReadFromJsonAsync<LoginResponse>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login!.Token);
        return client;
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _connection.Dispose();
    }
}
