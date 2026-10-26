using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Toni.Api.Auth;
using Toni.Api.Contracts;
using Toni.Api.Data;

namespace Toni.Api.Endpoints;

public static class PublicEndpoints
{
    public static void MapPublic(this RouteGroupBuilder api)
    {
        api.MapGet("/state", async (ToniDb db) =>
        {
            var people = await db.People.AsNoTracking().ToListAsync();
            var periods = await db.Periods.AsNoTracking().ToListAsync();
            var strikes = await db.Strikes.AsNoTracking().ToListAsync();
            var votes = await db.Votes.AsNoTracking().Include(v => v.Ballots)
                .Where(v => v.Status == VoteStatus.Offen).ToListAsync();
            // Sorted in memory: small tables, and SQLite (tests) cannot order by DateTimeOffset.
            return new StateDto(
                people.OrderBy(p => p.CreatedAt).Select(PersonDto.From).ToList(),
                periods.Select(PeriodDto.From).ToList(),
                strikes.Select(StrikeDto.From).ToList(),
                votes.OrderBy(v => v.CreatedAt).Select(VoteDto.From).ToList());
        });

        api.MapGet("/config", (IOptions<ToniOptions> o) => new ConfigDto(
            o.Value.DemoMode
                ? Seeder.DemoLogins.Select(d => new DemoLoginDto(d.Username, d.Password, d.Role)).ToList()
                : []));

        api.MapPost("/auth/login", async (LoginRequest req, ToniDb db, IPasswordHasher<User> hasher, TokenService tokens) =>
        {
            var name = req.Username?.Trim().ToLowerInvariant() ?? "";
            var user = await db.Users.FirstOrDefaultAsync(u => u.Username == name);
            var check = user is null ? PasswordVerificationResult.Failed : hasher.VerifyHashedPassword(user, user.PasswordHash, req.Password ?? "");
            if (user is null || check == PasswordVerificationResult.Failed)
                return Http.Error("Falscher Benutzername oder Passwort.", StatusCodes.Status401Unauthorized);
            if (check == PasswordVerificationResult.SuccessRehashNeeded)
            {
                user.PasswordHash = hasher.HashPassword(user, req.Password!);
                await db.SaveChangesAsync();
            }
            return Results.Ok(new LoginResponse(tokens.Issue(user), UserDto.From(user)));
        }).RequireRateLimiting("login");

        api.MapGet("/auth/me", (HttpContext http) => UserDto.From(CurrentUser.Get(http))).RequireAuthorization();
    }
}
