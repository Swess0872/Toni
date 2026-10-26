using System.Net;
using System.Net.Http.Json;
using Toni.Api.Contracts;

namespace Toni.Api.Tests;

public class ApiTests : IAsyncLifetime
{
    readonly ToniFactory _factory = new();

    public Task InitializeAsync() => _factory.InitializeAsync();
    public Task DisposeAsync() { _factory.Dispose(); return Task.CompletedTask; }

    async Task<StateDto> State(HttpClient c) => (await c.GetFromJsonAsync<StateDto>("/api/state"))!;

    [Fact]
    public async Task State_is_public_and_contains_demo_data()
    {
        var state = await State(_factory.CreateClient());
        Assert.Equal(6, state.People.Count);
        Assert.Single(state.Votes);
        Assert.NotEmpty(state.Strikes);
    }

    [Fact]
    public async Task Wrong_password_is_rejected()
    {
        var res = await _factory.CreateClient().PostAsJsonAsync("/api/auth/login", new LoginRequest("max", "falsch"));
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task Logged_out_users_cannot_add_strikes()
    {
        var client = _factory.CreateClient();
        var state = await State(client);
        var res = await client.PostAsJsonAsync("/api/strikes", new StrikeRequest(state.People[0].Id, state.Periods[0].Id, "Test-Strich"));
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task Member_adds_strike_but_cannot_use_admin_endpoints()
    {
        var lena = await _factory.LoginAsync("lena", "toni");
        var state = await State(lena);
        var before = state.Strikes.Count;

        var add = await lena.PostAsJsonAsync("/api/strikes", new StrikeRequest(state.People[2].Id, state.Periods[0].Id, "Abwasch vergessen"));
        add.EnsureSuccessStatusCode();
        Assert.Equal(before + 1, (await State(lena)).Strikes.Count);

        var admin = await lena.PostAsJsonAsync("/api/people", new PersonCreateRequest("Eve"));
        Assert.Equal(HttpStatusCode.Forbidden, admin.StatusCode);
    }

    [Fact]
    public async Task Accepted_vote_creates_strike_from_vote()
    {
        var max = await _factory.LoginAsync("max", "toni2026");
        var vote = (await State(max)).Votes.Single();

        // Seeded ballots: Max ja, Sophie nein. Jonas tips it to ja.
        var jonas = await _factory.LoginAsync("jonas", "toni");
        (await jonas.PutAsJsonAsync($"/api/votes/{vote.Id}/ballot", new BallotRequest("ja"))).EnsureSuccessStatusCode();
        var resolved = await (await jonas.PostAsync($"/api/votes/{vote.Id}/resolve", null)).Content.ReadFromJsonAsync<VoteDto>();

        Assert.Equal("angenommen", resolved!.Status);
        var state = await State(max);
        Assert.Empty(state.Votes);
        Assert.Contains(state.Strikes, s => s.Source == "abstimmung" && s.PersonId == vote.PersonId && s.Reason == vote.Reason);
    }

    [Fact]
    public async Task Tied_vote_is_rejected_without_strike()
    {
        var max = await _factory.LoginAsync("max", "toni2026");
        var vote = (await State(max)).Votes.Single();
        var before = (await State(max)).Strikes.Count;

        var resolved = await (await max.PostAsync($"/api/votes/{vote.Id}/resolve", null)).Content.ReadFromJsonAsync<VoteDto>();

        Assert.Equal("abgelehnt", resolved!.Status);
        Assert.Equal(before, (await State(max)).Strikes.Count);
    }

    [Fact]
    public async Task Removing_a_login_ends_its_session()
    {
        var max = await _factory.LoginAsync("max", "toni2026");
        var lena = await _factory.LoginAsync("lena", "toni");
        var users = await max.GetFromJsonAsync<List<UserDto>>("/api/users");
        (await max.DeleteAsync($"/api/users/{users!.Single(u => u.Username == "lena").Id}")).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.Unauthorized, (await lena.GetAsync("/api/auth/me")).StatusCode);
    }

    [Fact]
    public async Task Last_admin_cannot_be_demoted()
    {
        var max = await _factory.LoginAsync("max", "toni2026");
        var users = await max.GetFromJsonAsync<List<UserDto>>("/api/users");
        var res = await max.PatchAsJsonAsync($"/api/users/{users!.Single(u => u.Username == "max").Id}", new UserPatchRequest(null, null, "mitglied"));
        Assert.Equal(HttpStatusCode.Conflict, res.StatusCode);
    }

    [Fact]
    public async Task Deleting_a_person_removes_their_strikes_and_login()
    {
        var max = await _factory.LoginAsync("max", "toni2026");
        var jonas = (await State(max)).People.Single(p => p.Name == "Jonas");
        (await max.DeleteAsync($"/api/people/{jonas.Id}")).EnsureSuccessStatusCode();

        var state = await State(max);
        Assert.DoesNotContain(state.Strikes, s => s.PersonId == jonas.Id);
        var users = await max.GetFromJsonAsync<List<UserDto>>("/api/users");
        Assert.DoesNotContain(users!, u => u.Username == "jonas");
    }
}
