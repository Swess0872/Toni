using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.JsonWebTokens;
using Toni.Api.Data;

namespace Toni.Api.Auth;

public static class CurrentUser
{
    const string ItemKey = "toni.user";

    /// <summary>
    /// The token only carries the user id. Role and person link are looked up on
    /// every request, so a removed login or a changed role takes effect immediately.
    /// </summary>
    public static async Task OnTokenValidated(TokenValidatedContext ctx)
    {
        var sub = ctx.Principal?.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var db = ctx.HttpContext.RequestServices.GetRequiredService<ToniDb>();
        var user = Guid.TryParse(sub, out var id) ? await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id) : null;
        if (user is null)
        {
            ctx.Fail("Login existiert nicht mehr");
            return;
        }
        ctx.HttpContext.Items[ItemKey] = user;
        ctx.Principal = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()), new Claim("role", user.Role)],
            JwtBearerDefaults.AuthenticationScheme, "sub", "role"));
    }

    public static User Get(HttpContext http) =>
        http.Items[ItemKey] as User ?? throw new InvalidOperationException("Endpoint requires an authenticated user");
}
