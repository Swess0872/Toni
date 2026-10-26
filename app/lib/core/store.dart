import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'api.dart';
import 'models.dart';
import 'selectors.dart';

/// App-wide data and session. Every action goes to the server and then reloads
/// the state; the server also pushes "changed" via SignalR so other screens follow.
///
/// The last loaded state is kept on the device. Without a connection the app
/// shows that copy read-only and reconnects on its own once the server is back.
class ToniStore extends ChangeNotifier {
  ToniStore(this.api, this._prefs);

  static const _sessionKey = 'toni_session_v1';
  static const _cacheKey = 'toni_cache_v1';

  final ApiClient api;
  final SharedPreferences _prefs;

  ToniData data = const ToniData();
  AppUser? user;
  List<AppUser> users = [];
  List<DemoLogin> demoLogins = [];
  bool loaded = false;
  /// Error from the last reload that is not a lost connection (e.g. server error).
  String? connectionError;
  /// No connection to the server: data is the cached copy and changes are blocked.
  bool offline = false;
  /// When [data] was last loaded from the server.
  DateTime? dataAsOf;
  DateTime _lastReload = DateTime(0);

  Selectors? _sel;
  Selectors get sel => _sel ??= Selectors(data);

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  String? get myPersonId => user?.personId;

  HubConnection? _hub;
  Timer? _poll;
  Future<void>? _refreshing;

  Future<void> init() async {
    api.token = _prefs.getString(_sessionKey);
    _loadCache();
    await Future.wait([_loadConfig(), _loadMe()]);
    await refresh();
    _startLive();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      data = ToniData.fromJson(j['state'] as Map<String, dynamic>);
      dataAsOf = DateTime.parse(j['savedAt'] as String);
      // Only restore the session's user if the session itself is still there.
      if (api.token != null && j['user'] != null) user = AppUser.fromJson(j['user'] as Map<String, dynamic>);
      users = [for (final u in j['users'] as List? ?? const []) AppUser.fromJson(u as Map<String, dynamic>)];
      loaded = true;
      notifyListeners();
    } catch (_) {
      _prefs.remove(_cacheKey);
    }
  }

  void _saveCache(Map<String, dynamic> state, List<dynamic>? rawUsers) {
    _prefs.setString(_cacheKey, jsonEncode({
      'state': state,
      'savedAt': dataAsOf!.toIso8601String(),
      'user': user == null ? null : {'id': user!.id, 'username': user!.username, 'role': user!.role, 'personId': user!.personId},
      'users': ?rawUsers,
    }));
  }

  Future<void> _loadConfig() async {
    try {
      final j = await api.get('/config') as Map<String, dynamic>;
      demoLogins = [
        for (final d in j['demoLogins'] as List)
          DemoLogin(d['username'] as String, d['password'] as String, d['role'] as String),
      ];
    } on ApiException {
      demoLogins = [];
    }
  }

  Future<void> _loadMe() async {
    if (api.token == null) return;
    try {
      user = AppUser.fromJson(await api.get('/auth/me') as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.unauthorized) await _clearSession();
    }
  }

  /// Reloads everything; concurrent calls share one request.
  Future<void> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<void> _doRefresh() async {
    _lastReload = DateTime.now();
    try {
      final state = await api.get('/state') as Map<String, dynamic>;
      final rawUsers = isAdmin ? await api.get('/users') as List : null;
      data = ToniData.fromJson(state);
      if (rawUsers != null) users = [for (final u in rawUsers) AppUser.fromJson(u as Map<String, dynamic>)];
      dataAsOf = DateTime.now();
      _saveCache(state, rawUsers);
      connectionError = null;
      final wasOffline = offline;
      offline = false;
      if (wasOffline) {
        // Back online: catch up on everything that may have changed meanwhile.
        await Future.wait([_loadConfig(), _loadMe()]);
      }
      _ensureHub();
    } on ApiException catch (e) {
      if (e.unauthorized) await _clearSession();
      offline = e.offline;
      connectionError = e.offline ? null : e.message;
    }
    _sel = null;
    loaded = true;
    notifyListeners();
  }

  void _startLive() {
    // Every 10 s while offline (to notice the way back), otherwise every 30 s as a safety net.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (offline || DateTime.now().difference(_lastReload) >= const Duration(seconds: 30)) refresh();
    });
    final hub = HubConnectionBuilder()
        .withUrl('${api.baseUrl}/hubs/state')
        .withAutomaticReconnect(reconnectPolicy: _RetryForever())
        .build();
    hub.on('changed', (_) => refresh());
    _hub = hub;
    _ensureHub();
  }

  /// Starts the live connection if it is down (first start failed or it gave up).
  void _ensureHub() {
    final hub = _hub;
    if (hub == null || hub.state != HubConnectionState.Disconnected) return;
    hub.start()?.catchError((Object _) {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _hub?.stop();
    super.dispose();
  }

  // ---- Auth -----------------------------------------------------------------

  Future<void> login(String username, String password) async {
    final j = await api.post('/auth/login', {'username': username.trim(), 'password': password}) as Map<String, dynamic>;
    api.token = j['token'] as String;
    await _prefs.setString(_sessionKey, api.token!);
    user = AppUser.fromJson(j['user'] as Map<String, dynamic>);
    await refresh();
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    api.token = null;
    user = null;
    users = [];
    await _prefs.remove(_sessionKey);
  }

  Future<void> _do(Future<dynamic> Function() call) async {
    if (offline) throw ApiException(offlineMessage);
    await call();
    await refresh();
  }

  static const offlineMessage = 'Offline — Änderungen sind erst wieder mit Verbindung möglich.';

  // ---- Striche & Abstimmungen ----------------------------------------------

  Future<void> addStrike(String personId, String periodId, String reason) =>
      _do(() => api.post('/strikes', {'personId': personId, 'periodId': periodId, 'reason': reason}));

  Future<void> startVote(String personId, String periodId, String reason) =>
      _do(() => api.post('/votes', {'personId': personId, 'periodId': periodId, 'reason': reason}));

  Future<void> castVote(String voteId, String choice) =>
      _do(() => api.put('/votes/$voteId/ballot', {'choice': choice}));

  Future<void> resolveVote(String voteId) => _do(() => api.post('/votes/$voteId/resolve'));

  Future<void> removeStrike(String id) => _do(() => api.delete('/strikes/$id'));

  // ---- Profil ---------------------------------------------------------------

  Future<void> setMyColor(String color) => _do(() => api.put('/me/color', {'color': color}));

  Future<void> setMyAvatar(String? dataUrl) => _do(() => api.put('/me/avatar', {'avatar': dataUrl}));

  Future<void> changeMyPassword(String password) async {
    if (offline) throw ApiException(offlineMessage);
    await api.put('/me/password', {'password': password});
  }

  // ---- Admin: Personen & Logins --------------------------------------------

  Future<void> addPerson(String name) => _do(() => api.post('/people', {'name': name}));

  Future<void> updatePerson(String id, {String? name, bool? active, String? color}) => _do(() => api.patch('/people/$id', {
        'name': ?name,
        'active': ?active,
        'color': ?color,
      }));

  Future<void> removePerson(String id) => _do(() => api.delete('/people/$id'));

  AppUser? accountFor(String personId) {
    for (final u in users) {
      if (u.personId == personId) return u;
    }
    return null;
  }

  Future<void> addAccount(String personId, String username, String password, String role) => _do(() => api.post(
      '/users', {'personId': personId, 'username': username, 'password': password, 'role': role}));

  Future<void> updateUser(String id, {String? username, String? password, String? role}) =>
      _do(() => api.patch('/users/$id', {
            'username': ?username,
            'password': ?password,
            'role': ?role,
          }));

  Future<void> removeUser(String id) => _do(() => api.delete('/users/$id'));

  // ---- Admin: Perioden -----------------------------------------------------

  Future<void> addMonth(int month, int year) =>
      _do(() => api.post('/periods', {'type': 'monat', 'month': month, 'year': year}));

  Future<void> addFreitext(String label, int year, String? start, String? end) => _do(() => api.post('/periods', {
        'type': 'freitext',
        'label': label,
        'year': year,
        'start': ?start,
        'end': ?end,
      }));

  Future<void> updatePeriod(String id, {String? start, String? end}) =>
      _do(() => api.patch('/periods/$id', {'start': ?start, 'end': ?end}));

  Future<void> removePeriod(String id) => _do(() => api.delete('/periods/$id'));
}

/// Reconnect quickly at first, then every 30 seconds — and never give up.
class _RetryForever implements IRetryPolicy {
  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) =>
      const [0, 2000, 5000, 10000][retryContext.previousRetryCount.clamp(0, 3)] +
      (retryContext.previousRetryCount > 3 ? 20000 : 0);
}
