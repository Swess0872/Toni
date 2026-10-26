using Toni.Api.Data;

namespace Toni.Api.Contracts;

public record PersonDto(Guid Id, string Name, bool Active, string Color, string? Avatar)
{
    public static PersonDto From(Person p) => new(p.Id, p.Name, p.Active, p.Color, p.Avatar);
}

public record PeriodDto(Guid Id, string Type, int Year, int? Month, string? Label, DateOnly? Start, DateOnly? End, bool Active)
{
    public static PeriodDto From(Period p) => new(p.Id, p.Type, p.Year, p.Month, p.Label, p.Start, p.End, p.Active);
}

public record StrikeDto(Guid Id, Guid PersonId, Guid PeriodId, string Reason, DateTimeOffset CreatedAt, string Source)
{
    public static StrikeDto From(Strike s) => new(s.Id, s.PersonId, s.PeriodId, s.Reason, s.CreatedAt, s.Source);
}

public record VoteDto(
    Guid Id, Guid PersonId, Guid PeriodId, string Reason, Guid? CreatedBy, DateTimeOffset CreatedAt,
    string Status, DateTimeOffset? ResolvedAt, Dictionary<Guid, string> Ballots)
{
    public static VoteDto From(Vote v) => new(
        v.Id, v.PersonId, v.PeriodId, v.Reason, v.CreatedBy, v.CreatedAt, v.Status, v.ResolvedAt,
        v.Ballots.ToDictionary(b => b.PersonId, b => b.Choice));
}

public record UserDto(Guid Id, string Username, string Role, Guid? PersonId)
{
    public static UserDto From(User u) => new(u.Id, u.Username, u.Role, u.PersonId);
}

/// <summary>Everything the overview needs in one round trip; the client derives leaderboards from it.</summary>
public record StateDto(
    IReadOnlyList<PersonDto> People, IReadOnlyList<PeriodDto> Periods,
    IReadOnlyList<StrikeDto> Strikes, IReadOnlyList<VoteDto> Votes);

public record DemoLoginDto(string Username, string Password, string Role);
public record ConfigDto(IReadOnlyList<DemoLoginDto> DemoLogins);

public record LoginRequest(string Username, string Password);
public record LoginResponse(string Token, UserDto User);

public record StrikeRequest(Guid PersonId, Guid PeriodId, string Reason);
public record BallotRequest(string Choice);

public record PersonCreateRequest(string Name);
public record PersonPatchRequest(string? Name, bool? Active, string? Color);

public record UserCreateRequest(Guid PersonId, string Username, string Password, string Role);
public record UserPatchRequest(string? Username, string? Password, string? Role);

public record PeriodCreateRequest(string Type, int Year, int? Month, string? Label, DateOnly? Start, DateOnly? End);
public record PeriodPatchRequest(string? Label, DateOnly? Start, DateOnly? End, bool? Active);

public record ColorRequest(string Color);
public record AvatarRequest(string? Avatar);
public record PasswordRequest(string Password);

public record ErrorDto(string Error);
