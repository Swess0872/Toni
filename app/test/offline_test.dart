import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toni/core/api.dart';
import 'package:toni/core/store.dart';

const _state = {
  'people': [
    {'id': 'p1', 'name': 'Max', 'active': true, 'color': '#a3e635', 'avatar': null},
  ],
  'periods': <Object>[],
  'strikes': <Object>[],
  'votes': <Object>[],
};

/// Fake server that can be switched off like a lost connection.
class _Server {
  bool up = true;

  late final client = MockClient((req) async {
    if (!up) throw http.ClientException('offline');
    return switch (req.url.path) {
      '/api/state' => http.Response(jsonEncode(_state), 200),
      '/api/config' => http.Response(jsonEncode({'demoLogins': []}), 200),
      _ => http.Response('{}', 200),
    };
  });
}

Future<ToniStore> _start(_Server server) async {
  final store = ToniStore(ApiClient('http://toni.test', client: server.client), await SharedPreferences.getInstance());
  await store.init();
  addTearDown(store.dispose);
  return store;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('without connection the last saved state is shown read-only', () async {
    final server = _Server();
    await _start(server); // first run online: fills the cache

    server.up = false;
    final store = await _start(server); // app restart without network

    expect(store.offline, isTrue);
    expect(store.data.people.single.name, 'Max');
    expect(store.dataAsOf, isNotNull);
    expect(() => store.addPerson('Eve'), throwsA(isA<ApiException>()));
  });

  test('comes back online by itself on the next reload', () async {
    final server = _Server()..up = false;
    final store = await _start(server);
    expect(store.offline, isTrue);

    server.up = true;
    await store.refresh();

    expect(store.offline, isFalse);
    expect(store.data.people, hasLength(1));
  });
}
