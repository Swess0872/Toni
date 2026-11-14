import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toni/core/api.dart';
import 'package:toni/core/format.dart';
import 'package:toni/core/models.dart';
import 'package:toni/core/settings.dart';
import 'package:toni/core/store.dart';
import 'package:toni/ui/add_strike.dart';
import 'package:toni/ui/admin.dart';
import 'package:toni/ui/overview.dart';
import 'package:toni/ui/theme.dart';
import 'package:toni/ui/votes.dart';

// Long names like the real group's, which used to be cut off.
const _names = ['Dachs', 'Feivel', 'Merlin', 'Gecko', 'Sam', 'Papillon', 'Kovu', 'Sputnik', 'Malaika', 'Aloe'];

Map<String, dynamic> _vote(String id, String status, Map<String, String> ballots) => {
      'id': id, 'personId': 'p1', 'periodId': 'm', 'reason': 'Abwasch eine ganze Woche stehen lassen', 'createdBy': 'p0',
      'createdAt': '2026-11-10T10:00:00Z', 'status': status, 'resolvedAt': status == 'offen' ? null : '2026-11-11T10:00:00Z',
      'ballots': ballots,
    };

Future<ToniStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final now = DateTime.now();
  final history = [_vote('v2', 'angenommen', {'p0': 'ja', 'p2': 'ja', 'p3': 'nein'})];
  final api = ApiClient('http://toni.test', client: MockClient((req) async => http.Response(jsonEncode(history), 200)));
  final store = ToniStore(api, await SharedPreferences.getInstance())
    ..data = ToniData.fromJson({
      'people': [
        for (final (i, n) in _names.indexed) {'id': 'p$i', 'name': n, 'active': true, 'color': '#a3e635', 'avatar': null},
      ],
      'periods': [
        {'id': 'm', 'type': 'monat', 'year': now.year, 'month': now.month - 1, 'label': null,
          'start': isoDate(DateTime(now.year, now.month)), 'end': isoDate(DateTime(now.year, now.month + 1, 0)), 'active': true},
      ],
      'strikes': [
        for (var i = 0; i < 23; i++) {'id': 's$i', 'personId': 'p${i % 3}', 'periodId': 'm', 'reason': 'Grund $i', 'source': 'direkt', 'createdAt': '2026-11-01T10:00:00Z'},
      ],
      'votes': [_vote('v1', 'offen', {'p0': 'ja', 'p3': 'nein'})],
    })
    ..user = AppUser(id: 'u0', username: 'dachs', role: 'admin', personId: 'p0')
    ..users = [
      AppUser(id: 'u0', username: 'dachs', role: 'admin', personId: 'p0'),
      AppUser(id: 'u1', username: 'merlin', role: 'mitglied', personId: 'p2'),
    ];
  return store;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = await _store();
  final settings = Settings(await SharedPreferences.getInstance());
  await tester.pumpWidget(MultiProvider(
    providers: [ChangeNotifierProvider.value(value: settings), ChangeNotifierProvider.value(value: store)],
    child: MaterialApp(
      theme: buildTheme(settings, tv: false),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Any RenderFlex overflow fails the test, so these check the phone layouts.
  testWidgets('add strike: names are not cut off', (tester) async {
    await _pump(tester, const AddStrikeForm());
    expect(find.text('Papillon'), findsOneWidget);
  });

  testWidgets('admin people and periods fit a phone', (tester) async {
    await _pump(tester, const AdminDashboard());
    expect(find.text('Login entfernen'), findsWidgets);
    await tester.ensureVisible(find.text('Perioden'));
    await tester.tap(find.text('Perioden'));
    await tester.pump();
    expect(find.text('Perioden & Anlässe'), findsOneWidget);
  });

  testWidgets('overview with a running vote and many strikes', (tester) async {
    await _pump(tester, Overview(onRequireLogin: () {}));
    expect(find.text('Strich!'), findsOneWidget);
  });

  testWidgets('who voted what, live and past', (tester) async {
    await _pump(tester, Builder(builder: (context) {
      final store = context.watch<ToniStore>();
      return Column(children: [
        TextButton(onPressed: () => showVoteDetail(context, store.data.votes.single), child: const Text('live')),
        TextButton(onPressed: () => showVoteHistory(context), child: const Text('past')),
      ]);
    }));

    await tester.tap(find.text('live'));
    await tester.pumpAndSettle();
    expect(find.text('NOCH NICHT ABGESTIMMT · 8'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('past'));
    await tester.pumpAndSettle();
    expect(find.text('STRICH'), findsOneWidget);
    await tester.tap(find.text('Feivel'));
    await tester.pumpAndSettle();
    expect(find.text('STRICH! · 2'), findsOneWidget);
  });
}
