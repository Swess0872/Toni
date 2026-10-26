using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Toni.Api.Auth;
using Toni.Api.Contracts;
using Toni.Api.Data;

namespace Toni.Api.Endpoints;

public static class AdminEndpoints
{
    public static void MapAdmin(this RouteGroupBuilder api)
    {
        // ---- Striche & Abstimmungen ----
        api.MapDelete("/strikes/{id:guid}", async (Guid id, ToniDb db) =>
            await db.Strikes.Where(s => s.Id == id).ExecuteDeleteAsync() > 0 ? Results.NoContent() : Http.NotFound("Strich"));

        api.MapDelete("/votes/{id:guid}", async (Guid id, ToniDb db) =>
            await db.Votes.Where(v => v.Id == id).ExecuteDeleteAsync() > 0 ? Results.NoContent() : Http.NotFound("Abstimmung"));

        // ---- Personen ----
        api.MapPost("/people", async (PersonCreateRequest req, ToniDb db) =>
        {
            var name = req.Name?.Trim();
            if (string.IsNullOrEmpty(name) || name.Length > 60) return Http.Error("Name fehlt oder ist zu lang.");
            var person = new Person { Name = name, Color = Palette.ForIndex(await db.People.CountAsync()) };
            db.People.Add(person);
            await db.SaveChangesAsync();
            return Results.Ok(PersonDto.From(person));
        });

        api.MapPatch("/people/{id:guid}", async (Guid id, PersonPatchRequest req, ToniDb db) =>
        {
            var person = await db.People.FindAsync(id);
            if (person is null) return Http.NotFound("Person");
            if (req.Name is { } n)
            {
                n = n.Trim();
                if (n.Length is 0 or > 60) return Http.Error("Name fehlt oder ist zu lang.");
                person.Name = n;
            }
            if (req.Color is { } c)
            {
                if (!Palette.IsHexColor(c)) return Http.Error("Ungültige Farbe.");
                person.Color = c.ToLowerInvariant();
            }
            if (req.Active is { } active) person.Active = active;
            await db.SaveChangesAsync();
            return Results.Ok(PersonDto.From(person));
        });

        // Cascades to the person's strikes, votes, ballots and login (see ToniDb).
        api.MapDelete("/people/{id:guid}", async (Guid id, ToniDb db, HttpContext http) =>
        {
            if (CurrentUser.Get(http).PersonId == id) return Http.Error("Du kannst dich nicht selbst löschen.");
            if (await IsLastAdmin(db, u => u.PersonId == id)) return LastAdminError();
            return await db.People.Where(p => p.Id == id).ExecuteDeleteAsync() > 0 ? Results.NoContent() : Http.NotFound("Person");
        });

        // ---- Logins ----
        api.MapGet("/users", async (ToniDb db) =>
            (await db.Users.AsNoTracking().OrderBy(u => u.Username).ToListAsync()).Select(UserDto.From).ToList());

        api.MapPost("/users", async (UserCreateRequest req, ToniDb db, IPasswordHasher<User> hasher) =>
        {
            var username = req.Username?.Trim().ToLowerInvariant() ?? "";
            if (username.Length is < 2 or > 40) return Http.Error("Benutzername muss 2–40 Zeichen lang sein.");
            if ((req.Password ?? "").Length < 2) return Http.Error("Passwort ist zu kurz.");
            if (!Roles.IsValid(req.Role)) return Http.Error("Unbekannte Rolle.");
            if (!await db.People.AnyAsync(p => p.Id == req.PersonId)) return Http.NotFound("Person");
            if (await db.Users.AnyAsync(u => u.PersonId == req.PersonId)) return Http.Error("Diese Person hat bereits einen Login.", StatusCodes.Status409Conflict);
            if (await db.Users.AnyAsync(u => u.Username == username)) return Http.Error("Benutzername ist schon vergeben.", StatusCodes.Status409Conflict);
            var user = new User { Username = username, Role = req.Role, PersonId = req.PersonId };
            user.PasswordHash = hasher.HashPassword(user, req.Password!);
            db.Users.Add(user);
            await db.SaveChangesAsync();
            return Results.Ok(UserDto.From(user));
        });

        api.MapPatch("/users/{id:guid}", async (Guid id, UserPatchRequest req, ToniDb db, IPasswordHasher<User> hasher) =>
        {
            var user = await db.Users.FindAsync(id);
            if (user is null) return Http.NotFound("Login");
            if (req.Username is { } un)
            {
                un = un.Trim().ToLowerInvariant();
                if (un.Length is < 2 or > 40) return Http.Error("Benutzername muss 2–40 Zeichen lang sein.");
                if (await db.Users.AnyAsync(u => u.Username == un && u.Id != id)) return Http.Error("Benutzername ist schon vergeben.", StatusCodes.Status409Conflict);
                user.Username = un;
            }
            if (req.Password is { } pw)
            {
                if (pw.Length < 2) return Http.Error("Passwort ist zu kurz.");
                user.PasswordHash = hasher.HashPassword(user, pw);
            }
            if (req.Role is { } role)
            {
                if (!Roles.IsValid(role)) return Http.Error("Unbekannte Rolle.");
                if (role != Roles.Admin && await IsLastAdmin(db, u => u.Id == id)) return LastAdminError();
                user.Role = role;
            }
            await db.SaveChangesAsync();
            return Results.Ok(UserDto.From(user));
        });

        api.MapDelete("/users/{id:guid}", async (Guid id, ToniDb db) =>
        {
            if (await IsLastAdmin(db, u => u.Id == id)) return LastAdminError();
            return await db.Users.Where(u => u.Id == id).ExecuteDeleteAsync() > 0 ? Results.NoContent() : Http.NotFound("Login");
        });

        // ---- Perioden ----
        api.MapPost("/periods", async (PeriodCreateRequest req, ToniDb db) =>
        {
            Period period;
            if (req.Type == PeriodType.Monat)
            {
                if (req.Month is not (>= 0 and <= 11) || req.Year is < 2000 or > 2100) return Http.Error("Ungültiger Monat.");
                if (await db.Periods.AnyAsync(p => p.Type == PeriodType.Monat && p.Month == req.Month && p.Year == req.Year))
                    return Http.Error("Diesen Monat gibt es schon.", StatusCodes.Status409Conflict);
                period = Seeder.Month(req.Month.Value, req.Year);
            }
            else if (req.Type == PeriodType.Freitext)
            {
                var label = req.Label?.Trim();
                if (string.IsNullOrEmpty(label) || label.Length > 80) return Http.Error("Anlass-Name fehlt oder ist zu lang.");
                if (req.Start is { } s && req.End is { } e && e < s) return Http.Error("Ende liegt vor dem Start.");
                period = new Period
                {
                    Type = PeriodType.Freitext, Label = label, Start = req.Start, End = req.End,
                    Year = req.Start?.Year ?? (req.Year is >= 2000 and <= 2100 ? req.Year : DateTime.Today.Year),
                };
            }
            else return Http.Error("Unbekannter Zeitraum-Typ.");
            db.Periods.Add(period);
            await db.SaveChangesAsync();
            return Results.Ok(PeriodDto.From(period));
        });

        api.MapPatch("/periods/{id:guid}", async (Guid id, PeriodPatchRequest req, ToniDb db) =>
        {
            var period = await db.Periods.FindAsync(id);
            if (period is null) return Http.NotFound("Zeitraum");
            if (req.Label is { } l && period.Type == PeriodType.Freitext)
            {
                l = l.Trim();
                if (l.Length is 0 or > 80) return Http.Error("Anlass-Name fehlt oder ist zu lang.");
                period.Label = l;
            }
            if (req.Start is { } s) period.Start = s;
            if (req.End is { } e) period.End = e;
            if (period.Start is { } ps && period.End is { } pe && pe < ps) return Http.Error("Ende liegt vor dem Start.");
            if (req.Active is { } a) period.Active = a;
            await db.SaveChangesAsync();
            return Results.Ok(PeriodDto.From(period));
        });

        // Cascades to the period's strikes and votes.
        api.MapDelete("/periods/{id:guid}", async (Guid id, ToniDb db) =>
            await db.Periods.Where(p => p.Id == id).ExecuteDeleteAsync() > 0 ? Results.NoContent() : Http.NotFound("Zeitraum"));
    }

    /// <summary>True if the users matching <paramref name="target"/> include every remaining admin.</summary>
    static async Task<bool> IsLastAdmin(ToniDb db, System.Linq.Expressions.Expression<Func<User, bool>> target)
    {
        var admins = await db.Users.CountAsync(u => u.Role == Roles.Admin);
        var targeted = await db.Users.Where(u => u.Role == Roles.Admin).CountAsync(target);
        return targeted > 0 && targeted >= admins;
    }

    static IResult LastAdminError() =>
        Http.Error("Es muss mindestens ein Admin bleiben.", StatusCodes.Status409Conflict);
}
