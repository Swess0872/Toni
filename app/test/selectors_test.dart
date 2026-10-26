import 'package:flutter_test/flutter_test.dart';
import 'package:toni/core/format.dart';
import 'package:toni/core/models.dart';
import 'package:toni/core/selectors.dart';

Person person(String id) => Person(id: id, name: id, active: true, color: '#a3e635');

Period month(String id, int m, int y) {
  final start = DateTime(y, m + 1, 1);
  final end = DateTime(y, m + 2, 0);
  return Period(id: id, type: 'monat', year: y, month: m, start: isoDate(start), end: isoDate(end));
}

Strike strike(String person, String period) =>
    Strike(id: '$person-$period-${DateTime.now().microsecondsSinceEpoch}', personId: person, periodId: period, reason: 'x', createdAt: DateTime(2026), source: 'direkt');

void main() {
  test('roman numerals', () {
    expect(toRoman(14), 'XIV');
    expect(toRoman(1994), 'MCMXCIV');
    expect(toRoman(0), '—');
  });

  test('period range is formatted like de-DE short dates', () {
    expect(periodRange(month('p', 9, 2026)), '1. Okt. – 31. Okt. 2026');
  });

  test('timeAgo', () {
    final now = DateTime(2026, 10, 26, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 10)), now), 'gerade eben');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), 'vor 5 Min');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now), 'vor 3 Std');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now), 'vor 1 Tag');
    expect(timeAgo(now.subtract(const Duration(days: 4)), now), 'vor 4 Tagen');
  });

  group('wins', () {
    final a = person('a'), b = person('b'), c = person('c');
    final data = ToniData(
      people: [a, b, c],
      periods: [month('jan', 0, 2025), month('feb', 1, 2025), month('jan26', 0, 2026), month('okt26', 9, 2026)],
      strikes: [
        strike('a', 'jan'), strike('a', 'jan'), strike('b', 'jan'),
        strike('a', 'feb'),
        strike('b', 'jan26'), strike('b', 'jan26'),
        strike('a', 'okt26'), strike('c', 'okt26'),
      ],
    );
    final sel = Selectors(data, now: DateTime(2026, 10, 26));

    test('current period is the live month', () => expect(sel.currentPeriod?.id, 'okt26'));

    test('ties give several period winners', () => expect(sel.periodWinners('okt26'), unorderedEquals(['a', 'c'])));

    test('year wins count won periods', () {
      final board = sel.yearWins(2025);
      expect(board.first.person.id, 'a');
      expect(board.first.count, 2);
    });

    test('year titles roll up yearly champions', () {
      final titles = {for (final r in sel.yearTitles()) r.person.id: r.count};
      // 2025: a (2 months). 2026: a, b and c each won one period → all three champions.
      expect(titles, {'a': 2, 'b': 1, 'c': 1});
    });

    test('leaderboard sorts by count, then name', () {
      final rows = sel.leaderboard(const PeriodScope('jan'));
      expect(rows.map((r) => r.person.id), ['a', 'b', 'c']);
      expect(rows.map((r) => r.count), [2, 1, 0]);
    });

    test('deactivated people stay in rankings but cannot be picked', () {
      final off = Person(id: 'off', name: 'off', active: false, color: '#a3e635');
      final s = Selectors(
        ToniData(people: [a, off], periods: data.periods, strikes: [strike('off', 'jan'), strike('off', 'jan')]),
        now: DateTime(2026, 10, 26),
      );
      expect(s.leaderboard(const PeriodScope('jan')).first.person.id, 'off');
      expect(s.periodWinners('jan'), ['off']);
      expect(s.activePeople.map((p) => p.id), ['a']);
    });

    test('breakdown groups newest period first', () {
      expect(sel.breakdownByPeriod('a').map((g) => g.$1?.id), ['okt26', 'feb', 'jan']);
    });
  });
}
