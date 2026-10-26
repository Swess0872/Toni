using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Toni.Api.Auth;
using Toni.Api.Contracts;
using Toni.Api.Data;

namespace Toni.Api.Endpoints;

public static class MemberEndpoints
{
    const int MaxAvatarLength = 400_000;

    public static void MapMember(this RouteGroupBuilder api)
    {
        api.MapPost("/strikes", async (StrikeRequest req, ToniDb db) =>
        {
            if (Http.CleanReason(req.Reason) is not { } reason) return Http.Error(Http.ReasonError);
            if (!await db.People.AnyAsync(p => p.Id == req.PersonId && p.Active)) return Http.NotFound("Person");
            if (!await db.Periods.AnyAsync(p => p.Id == req.PeriodId)) return Http.NotFound("Zeitraum");
            var strike = new Strike { PersonId = req.PersonId, PeriodId = req.PeriodId, Reason = reason };
            db.Strikes.Add(strike);
            await db.SaveChangesAsync();
            return Results.Ok(StrikeDto.From(strike));
        });

        api.MapPost("/votes", async (StrikeRequest req, ToniDb db, HttpContext http) =>
        {
            if (Http.CleanReason(req.Reason) is not { } reason) return Http.Error(Http.ReasonError);
            if (!await db.People.AnyAsync(p => p.Id == req.PersonId && p.Active)) return Http.NotFound("Person");
            if (!await db.Periods.AnyAsync(p => p.Id == req.PeriodId)) return Http.NotFound("Zeitraum");
            var vote = new Vote
            {
                PersonId = req.PersonId, PeriodId = req.PeriodId, Reason = reason,
                CreatedBy = CurrentUser.Get(http).PersonId,
            };
            db.Votes.Add(vote);
            await db.SaveChangesAsync();
            return Results.Ok(VoteDto.From(vote));
        });

        api.MapPut("/votes/{id:guid}/ballot", async (Guid id, BallotRequest req, ToniDb db, HttpContext http) =>
        {
            if (req.Choice is not ("ja" or "nein")) return Http.Error("Stimme muss \"ja\" oder \"nein\" sein.");
            if (CurrentUser.Get(http).PersonId is not { } me)
                return Http.Error("Dieser Zugang ist keiner Person zugeordnet und kann nicht abstimmen.", StatusCodes.Status403Forbidden);
            var vote = await db.Votes.Include(v => v.Ballots).FirstOrDefaultAsync(v => v.Id == id);
            if (vote is null) return Http.NotFound("Abstimmung");
            if (vote.Status != VoteStatus.Offen) return Http.Error("Die Abstimmung ist bereits ausgewertet.", StatusCodes.Status409Conflict);
            var ballot = vote.Ballots.FirstOrDefault(b => b.PersonId == me);
            if (ballot is null) vote.Ballots.Add(new Ballot { PersonId = me, Choice = req.Choice });
            else ballot.Choice = req.Choice;
            await db.SaveChangesAsync();
            return Results.Ok(VoteDto.From(vote));
        });

        api.MapPost("/votes/{id:guid}/resolve", async (Guid id, ToniDb db) =>
        {
            var vote = await db.Votes.Include(v => v.Ballots).FirstOrDefaultAsync(v => v.Id == id);
            if (vote is null) return Http.NotFound("Abstimmung");
            if (vote.Status != VoteStatus.Offen) return Http.Error("Die Abstimmung ist bereits ausgewertet.", StatusCodes.Status409Conflict);
            if (vote.Ballots.Count == 0) return Http.Error("Noch keine Stimmen abgegeben.");
            var ja = vote.Ballots.Count(b => b.Choice == "ja");
            var nein = vote.Ballots.Count - ja;
            vote.Status = ja > nein ? VoteStatus.Angenommen : VoteStatus.Abgelehnt;
            vote.ResolvedAt = DateTimeOffset.UtcNow;
            if (vote.Status == VoteStatus.Angenommen)
            {
                db.Strikes.Add(new Strike
                {
                    PersonId = vote.PersonId, PeriodId = vote.PeriodId, Reason = vote.Reason, Source = StrikeSource.Abstimmung,
                });
            }
            await db.SaveChangesAsync();
            return Results.Ok(VoteDto.From(vote));
        });

        var me = api.MapGroup("/me");

        me.MapPut("/color", async (ColorRequest req, ToniDb db, HttpContext http) =>
        {
            if (!Palette.IsHexColor(req.Color)) return Http.Error("Ungültige Farbe.");
            if (await MyPerson(db, http) is not { } person) return NoPerson();
            person.Color = req.Color.ToLowerInvariant();
            await db.SaveChangesAsync();
            return Results.Ok(PersonDto.From(person));
        });

        me.MapPut("/avatar", async (AvatarRequest req, ToniDb db, HttpContext http) =>
        {
            if (req.Avatar is { } a && (a.Length > MaxAvatarLength || !a.StartsWith("data:image/", StringComparison.Ordinal)))
                return Http.Error("Ungültiges Profilbild.");
            if (await MyPerson(db, http) is not { } person) return NoPerson();
            person.Avatar = req.Avatar;
            await db.SaveChangesAsync();
            return Results.Ok(PersonDto.From(person));
        });

        me.MapPut("/password", async (PasswordRequest req, ToniDb db, HttpContext http, IPasswordHasher<User> hasher) =>
        {
            if ((req.Password ?? "").Length < 2) return Http.Error("Passwort ist zu kurz.");
            var user = await db.Users.FirstAsync(u => u.Id == CurrentUser.Get(http).Id);
            user.PasswordHash = hasher.HashPassword(user, req.Password!);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });
    }

    static async Task<Person?> MyPerson(ToniDb db, HttpContext http) =>
        CurrentUser.Get(http).PersonId is { } id ? await db.People.FirstOrDefaultAsync(p => p.Id == id) : null;

    static IResult NoPerson() =>
        Http.Error("Dieser Zugang ist keiner Person zugeordnet — Farbe und Bild kann nur eine zugeordnete Person setzen.",
            StatusCodes.Status403Forbidden);
}
