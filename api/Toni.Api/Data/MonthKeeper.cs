using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Toni.Api.Hubs;

namespace Toni.Api.Data;

/// <summary>
/// Creates the current month as a period as soon as it starts, so nobody has to
/// remember it and strikes never land in last month by default.
/// </summary>
public class MonthKeeper(IServiceScopeFactory scopes, IHubContext<StateHub> hub, IHostEnvironment env, ILogger<MonthKeeper> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stop)
    {
        if (env.IsEnvironment("Testing")) return;
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(10));
        do
        {
            try
            {
                if (await EnsureCurrentMonthAsync(DateOnly.FromDateTime(DateTime.Now), stop))
                    await hub.Clients.All.SendAsync(StateHub.Changed, stop);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogWarning(e, "Aktueller Monat konnte nicht angelegt werden");
            }
        } while (await timer.WaitForNextTickAsync(stop));
    }

    /// <summary>Adds the month of <paramref name="today"/> if it is missing. True if it was added.</summary>
    public async Task<bool> EnsureCurrentMonthAsync(DateOnly today, CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ToniDb>();
        var month = today.Month - 1;
        if (await db.Periods.AnyAsync(p => p.Type == PeriodType.Monat && p.Month == month && p.Year == today.Year, ct)) return false;
        db.Periods.Add(Seeder.Month(month, today.Year));
        await db.SaveChangesAsync(ct);
        log.LogInformation("Monat {Month}/{Year} angelegt", today.Month, today.Year);
        return true;
    }
}
