namespace Toni.Api.Data;

public static class PeriodType
{
    public const string Monat = "monat";
    public const string Freitext = "freitext";
}

public static class StrikeSource
{
    public const string Direkt = "direkt";
    public const string Abstimmung = "abstimmung";
}

public static class VoteStatus
{
    public const string Offen = "offen";
    public const string Angenommen = "angenommen";
    public const string Abgelehnt = "abgelehnt";
}

public static class Roles
{
    public const string Admin = "admin";
    public const string Mitglied = "mitglied";

    public static bool IsValid(string? role) => role is Admin or Mitglied;
}

public class Person
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Name { get; set; }
    public bool Active { get; set; } = true;
    public required string Color { get; set; }
    /// <summary>256×256 JPEG as data URL, cropped client-side.</summary>
    public string? Avatar { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public class Period
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Type { get; set; }
    public int Year { get; set; }
    /// <summary>0-based month (Januar = 0), only for <see cref="PeriodType.Monat"/>.</summary>
    public int? Month { get; set; }
    /// <summary>Only for <see cref="PeriodType.Freitext"/>.</summary>
    public string? Label { get; set; }
    public DateOnly? Start { get; set; }
    public DateOnly? End { get; set; }
    public bool Active { get; set; } = true;
}

public class Strike
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PersonId { get; set; }
    public Guid PeriodId { get; set; }
    public required string Reason { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public string Source { get; set; } = StrikeSource.Direkt;
}

public class Vote
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PersonId { get; set; }
    public Guid PeriodId { get; set; }
    public required string Reason { get; set; }
    /// <summary>Person who proposed the vote; null once that person is deleted.</summary>
    public Guid? CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public string Status { get; set; } = VoteStatus.Offen;
    public DateTimeOffset? ResolvedAt { get; set; }
    public List<Ballot> Ballots { get; set; } = [];
}

public class Ballot
{
    public Guid VoteId { get; set; }
    public Guid PersonId { get; set; }
    /// <summary>"ja" or "nein".</summary>
    public required string Choice { get; set; }
}

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Username { get; set; }
    public string PasswordHash { get; set; } = "";
    public string Role { get; set; } = Roles.Mitglied;
    public Guid? PersonId { get; set; }
}
