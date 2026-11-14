import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toni/core/api.dart';
import 'package:toni/core/store.dart';

/// Fake server whose /api/state answer can be held back, like a slow request.
class _Server {
  final people = <String>['Max'];
  Completer<void>? hold;

  late final client = MockClient((req) async {
    return switch (req.url.path) {
      '/api/state' => await _state(),
      '/api/config' => http.Response(jsonEncode({'demoLogins': []}), 200),
      _ => http.Response('{}', 200),
    };
  });

  Future<http.Response> _state() async {
    // Snapshot when the request arrives, answer later.
    final body = jsonEncode({
      'people': [
        for (final (i, name) in people.indexed) {'id': 'p$i', 'name': name, 'active': true, 'color': '#a3e635', 'avatar': null},
      ],
      'periods': <Object>[],
      'strikes': <Object>[],
      'votes': <Object>[],
    });
    await hold?.future;
    return http.Response(body, 200);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a change during a running reload is not lost', () async {
    final server = _Server();
    final store = ToniStore(ApiClient('http://toni.test', client: server.client), await SharedPreferences.getInstance());
    await store.init();
    addTearDown(store.dispose);

    server.hold = Completer();
    final first = store.refresh(); // started before the change, answers with old data
    await Future<void>.delayed(Duration.zero);
    server.people.add('Eve');
    final second = store.refresh(); // e.g. the "changed" push or the own action
    server.hold!.complete();
    server.hold = null;
    await Future.wait([first, second]);

    expect(store.data.people.map((p) => p.name), ['Max', 'Eve']);
  });
}
