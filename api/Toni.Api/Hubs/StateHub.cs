using Microsoft.AspNetCore.SignalR;

namespace Toni.Api.Hubs;

/// <summary>
/// Clients only listen. After every successful change the server sends "changed",
/// and clients reload <c>/api/state</c>. That keeps live votes in sync on every screen.
/// </summary>
public class StateHub : Hub
{
    public const string Path = "/hubs/state";
    public const string Changed = "changed";
}

public static class BroadcastExtensions
{
    /// <summary>Notifies all connected clients after an endpoint in the group succeeds.</summary>
    public static RouteGroupBuilder BroadcastChanges(this RouteGroupBuilder group) =>
        group.AddEndpointFilter(async (ctx, next) =>
        {
            var result = await next(ctx);
            if (result is not IStatusCodeHttpResult { StatusCode: >= 400 })
            {
                var hub = ctx.HttpContext.RequestServices.GetRequiredService<IHubContext<StateHub>>();
                await hub.Clients.All.SendAsync(StateHub.Changed);
            }
            return result;
        });
}
