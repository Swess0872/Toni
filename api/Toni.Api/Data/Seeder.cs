using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Toni.Api.Data;

public class Seeder(ToniDb db, IPasswordHasher<User> hasher, IOptions<ToniOptions> options, ILogger<Seeder> log)
{
    public static readonly (string Username, string Password, string Role)[] DemoLogins =
    [
        ("max", "toni2026", Roles.Admin),
        ("lena", "toni", Roles.Mitglied),
        ("jonas", "toni", Roles.Mitglied),
    ];

    static readonly string[] Reasons =
    [
        "Abwasch eine ganze Woche stehen lassen",
        "Letztes Bier aus dem Kühlschrank weggetrunken",
        "Mülltonne wieder nicht rausgestellt",
        "Mit Schuhen aufs Sofa gelegt",
        "Klopapier leer und nicht nachgefüllt",
        "Um 4 Uhr laut nach Hause gekommen",
        "Pfandkisten seit 3 Wochen im Flur",
        "Gemeinsame Kasse vergessen aufzufüllen",
        "Lautsprecher um Mitternacht aufgedreht",
        "Pizza im Ofen vergessen → Rauchmelder",
        "Spülmaschine falsch eingeräumt (Streit-Modus)",
        "Toaster mal wieder nicht ausgekratzt",
        "Skipass am ersten Tag verloren",
        "Beim Après-Ski eingeschlafen",
        "Um Mitternacht Feuerwerk im Innenhof",
    ];

    public async Task RunAsync()
    {
        var o = options.Value;
        if (await db.Users.AnyAsync()) return;

        if (o.DemoMode)
        {
            await SeedDemoAsync();
            log.LogInformation("Demo-Daten angelegt");
            return;
        }

        if (string.IsNullOrWhiteSpace(o.AdminUsername) || string.IsNullOrWhiteSpace(o.AdminPassword))
        {
            log.LogWarning("Keine Logins vorhanden und kein Toni:AdminUsername/AdminPassword gesetzt — niemand kann sich anmelden");
            return;
        }

        var person = new Person { Name = o.AdminName ?? Capitalize(o.AdminUsername), Color = Palette.ForIndex(0) };
        var admin = new User { Username = o.AdminUsername.Trim().ToLowerInvariant(), Role = Roles.Admin, PersonId = person.Id };
        admin.PasswordHash = hasher.HashPassword(admin, o.AdminPassword);
        db.People.Add(person);
        db.Users.Add(admin);
        if (!await db.Periods.AnyAsync())
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            db.Periods.Add(Month(today.Month - 1, today.Year));
        }
        await db.SaveChangesAsync();
        log.LogInformation("Admin-Login {User} angelegt", admin.Username);
    }

    public static Period Month(int month, int year)
    {
        var start = new DateOnly(year, month + 1, 1);
        return new Period
        {
            Type = PeriodType.Monat, Month = month, Year = year,
            Start = start, End = start.AddMonths(1).AddDays(-1),
        };
    }

    static string Capitalize(string s) => s.Length == 0 ? s : char.ToUpperInvariant(s[0]) + s[1..];

    // Same group as the prototype, but with dates relative to today so that
    // there is always a live month, a live occasion and a few past years.
    async Task SeedDemoAsync()
    {
        string[] names = ["Max", "Lena", "Jonas", "Sophie", "Tim", "Nina"];
        int[] colors = [0, 2, 3, 4, 1, 6];
        var people = names.Select((n, i) => new Person { Name = n, Color = Palette.Colors[colors[i]] }).ToList();
        db.People.AddRange(people);

        var today = DateOnly.FromDateTime(DateTime.Today);
        var periods = new List<Period>();
        var seen = new HashSet<(int, int)>();
        void AddMonth(DateOnly d)
        {
            if (seen.Add((d.Year, d.Month))) periods.Add(Month(d.Month - 1, d.Year));
        }
        for (var i = 6; i >= 0; i--) AddMonth(today.AddMonths(-i));
        foreach (var m in new[] { 9, 10, 11 }) AddMonth(new DateOnly(today.Year - 2, m + 1, 1));
        foreach (var m in new[] { 8, 9, 10 }) AddMonth(new DateOnly(today.Year - 1, m + 1, 1));

        periods.Add(new Period
        {
            Type = PeriodType.Freitext, Label = $"Skiurlaub {today.Year}", Year = today.Year,
            Start = new DateOnly(today.Year, 2, 7), End = new DateOnly(today.Year, 2, 14),
        });
        periods.Add(new Period
        {
            Type = PeriodType.Freitext, Label = $"Silvester '{(today.Year - 1) % 100:00}", Year = today.Year - 1,
            Start = new DateOnly(today.Year - 1, 12, 30), End = new DateOnly(today.Year, 1, 1),
        });
        periods.Add(new Period
        {
            Type = PeriodType.Freitext, Label = $"Hüttenwochenende {today.Year}", Year = today.Year,
            Start = today.AddDays(-2), End = today.AddDays(5),
        });
        db.Periods.AddRange(periods);

        var rnd = new Random(42);
        var ri = 0;
        foreach (var p in periods)
        {
            var last = p.End!.Value < today ? p.End.Value : today;
            var span = Math.Max(0, last.DayNumber - p.Start!.Value.DayNumber);
            // Jonas is the all-time champion of the older years, like in the prototype.
            var favorite = p.Year < today.Year ? people[2] : people[rnd.Next(people.Count)];
            foreach (var person in people.OrderBy(_ => rnd.Next()).Take(rnd.Next(2, 4)).Append(favorite).Distinct())
            {
                var n = person == favorite ? rnd.Next(2, 4) : rnd.Next(1, 3);
                for (var i = 0; i < n; i++)
                {
                    var day = p.Start.Value.AddDays(rnd.Next(span + 1));
                    db.Strikes.Add(new Strike
                    {
                        PersonId = person.Id, PeriodId = p.Id, Reason = Reasons[ri++ % Reasons.Length],
                        CreatedAt = new DateTimeOffset(day.ToDateTime(new TimeOnly(19, 30)), TimeSpan.Zero),
                    });
                }
            }
        }

        var currentMonth = periods.First(p => p.Type == PeriodType.Monat && p.Year == today.Year && p.Month == today.Month - 1);
        var vote = new Vote
        {
            PersonId = people[1].Id, PeriodId = currentMonth.Id, CreatedBy = people[2].Id,
            Reason = "Hat behauptet sie hätte abgewaschen — Beweis: voller Spülbecken-Turm",
            CreatedAt = DateTimeOffset.UtcNow.AddHours(-3),
        };
        vote.Ballots.Add(new Ballot { PersonId = people[0].Id, Choice = "ja" });
        vote.Ballots.Add(new Ballot { PersonId = people[3].Id, Choice = "nein" });
        db.Votes.Add(vote);

        for (var i = 0; i < DemoLogins.Length; i++)
        {
            var (username, password, role) = DemoLogins[i];
            var u = new User { Username = username, Role = role, PersonId = people[i].Id };
            u.PasswordHash = hasher.HashPassword(u, password);
            db.Users.Add(u);
        }

        await db.SaveChangesAsync();
    }
}
