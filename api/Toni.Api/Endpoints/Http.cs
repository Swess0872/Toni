using Toni.Api.Contracts;

namespace Toni.Api.Endpoints;

static class Http
{
    public static IResult Error(string message, int status = StatusCodes.Status400BadRequest) =>
        Results.Json(new ErrorDto(message), statusCode: status);

    public static IResult NotFound(string what) => Error($"{what} nicht gefunden.", StatusCodes.Status404NotFound);

    public static string? CleanReason(string? reason)
    {
        var r = reason?.Trim();
        return r is { Length: > 2 and <= 140 } ? r : null;
    }

    public const string ReasonError = "Begründung muss 3–140 Zeichen lang sein.";
}
