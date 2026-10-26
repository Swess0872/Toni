import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'api.dart';
import 'models.dart';
import 'selectors.dart';

/// App-wide data and session. Every action goes to the server and then reloads
/// the state; the server also pushes "changed" via SignalR so other screens follow.
class ToniStore extends ChangeNotifier {
  ToniStore(this.api, this._prefs);

  static const _sessionKey = 'toni_session_v1';

  final ApiClient api;
  final SharedPreferences _prefs;

  ToniData data = const ToniData();
  AppUser? user;
  List<AppUser> users = [];
  List<DemoLogin> demoLogins = [];
  bool loaded = false;
  String? connectionError;

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
    await Future.wait([_loadConfig(), _loadMe()]);
    await refresh();
    _startLive();
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
    try {
      data = ToniData.fromJson(await api.get('/state') as Map<String, dynamic>);
      if (isAdmin) {
        users = [for (final u in await api.get('/users') as List) AppUser.fromJson(u as Map<String, dynamic>)];
      }
      connectionError = null;
    } on ApiException catch (e) {
      if (e.unauthorized) await _clearSession();
      connectionError = e.message;
    }
    _sel = null;
    loaded = true;
    notifyListeners();
  }

  void _startLive() {
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    final hub = HubConnectionBuilder().withUrl('${api.baseUrl}/hubs/state').withAutomaticReconnect().build();
    hub.on('changed', (_) => refresh());
    _hub = hub;
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
    await call();
    await refresh();
  }

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

  Future<void> changeMyPassword(String password) => api.put('/me/password', {'password': password});

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
