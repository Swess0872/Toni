using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Toni.Api.Data;

namespace Toni.Api.Auth;

public class TokenService(IOptions<ToniOptions> options)
{
    public const string Issuer = "toni";

    public static SymmetricSecurityKey SigningKey(string jwtKey) => new(Encoding.UTF8.GetBytes(jwtKey));

    public string Issue(User user)
    {
        var o = options.Value;
        return new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = Issuer,
            Audience = Issuer,
            Subject = new ClaimsIdentity([new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString())]),
            Expires = DateTime.UtcNow.AddDays(o.SessionDays),
            SigningCredentials = new SigningCredentials(SigningKey(o.JwtKey), SecurityAlgorithms.HmacSha256),
        });
    }
}
