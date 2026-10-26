import 'format.dart';
import 'models.dart';

/// Derived views over the raw data. Ports the selectors of the prototype store.
class Selectors {
  Selectors(this.data, {DateTime? now}) : now = now ?? DateTime.now();

  final ToniData data;
  final DateTime now;

  late final List<Person> activePeople = data.people.where((p) => p.active).toList();

  late final Map<String, Person> _people = {for (final p in data.people) p.id: p};
  late final Map<String, Period> _periods = {for (final p in data.periods) p.id: p};

  Person? person(String? id) => id == null ? null : _people[id];
  Period? period(String? id) => id == null ? null : _periods[id];

  bool live(Period p) => isPeriodLive(p, now);

  /// First live month, else any live period, else the newest month, else anything.
  late final Period? currentPeriod = () {
    final months = data.periods.where((p) => p.isMonat).toList()
      ..sort((a, b) => b.year != a.year ? b.year - a.year : (b.month ?? 0) - (a.month ?? 0));
    for (final p in months) {
      if (live(p)) return p;
    }
    for (final p in data.periods) {
      if (live(p)) return p;
    }
    if (months.isNotEmpty) return months.first;
    return data.periods.isEmpty ? null : data.periods.first;
  }();

  int get currentYear => currentPeriod?.year ?? now.year;

  /// All periods live today (months first), falling back to the current period.
  List<Period> livePeriods() {
    final l = data.periods.where(live).toList()
      ..sort((a, b) {
        final t = (a.isMonat ? 0 : 1) - (b.isMonat ? 0 : 1);
        return t != 0 ? t : (a.start ?? '').compareTo(b.start ?? '');
      });
    if (l.isNotEmpty) return l;
    return currentPeriod == null ? [] : [currentPeriod!];
  }

  List<Vote> get openVotes => data.votes.where((v) => v.status == 'offen').toList();

  /// Periods newest first: by year, then months by month, occasions after months.
  List<Period> periodsNewestFirst() => [...data.periods]..sort(_newestFirst);

  static int _newestFirst(Period a, Period b) {
    if (b.year != a.year) return b.year - a.year;
    return (b.isMonat ? b.month! : 99) - (a.isMonat ? a.month! : 99);
  }

  List<Ranked> _sorted(Iterable<Ranked> rows) => rows.toList()
    ..sort((a, b) => b.count != a.count ? b.count - a.count : a.person.name.compareTo(b.person.name));

  List<Ranked> leaderboard(Scope scope) {
    bool inScope(Strike s) => switch (scope) {
          PeriodScope(:final periodId) => s.periodId == periodId,
          YearScope(:final year) => period(s.periodId)?.year == year,
          AllScope() => true,
        };
    final counts = <String, int>{};
    for (final s in data.strikes.where(inScope)) {
      counts[s.personId] = (counts[s.personId] ?? 0) + 1;
    }
    return _sorted(data.people.map((p) => Ranked(p, counts[p.id] ?? 0)));
  }

  final Map<String, List<String>> _winners = {};

  /// Person(s) with the most (> 0) strikes in a period; ties give several winners.
  List<String> periodWinners(String periodId) => _winners.putIfAbsent(periodId, () {
        final counts = <String, int>{for (final p in data.people) p.id: 0};
        for (final s in data.strikes) {
          if (s.periodId == periodId && counts.containsKey(s.personId)) counts[s.personId] = counts[s.personId]! + 1;
        }
        final max = counts.values.fold(0, (m, c) => c > m ? c : m);
        return max > 0 ? [for (final e in counts.entries) if (e.value == max) e.key] : <String>[];
      });

  List<Ranked> _winsBoard(Iterable<Period> periods) {
    final wins = <String, int>{};
    for (final per in periods) {
      for (final pid in periodWinners(per.id)) {
        wins[pid] = (wins[pid] ?? 0) + 1;
      }
    }
    return _sorted(data.people.map((p) => Ranked(p, wins[p.id] ?? 0)));
  }

  /// Monthly (and occasion) wins per person in a year — the "Jahr" board.
  List<Ranked> yearWins(int year) => _winsBoard(data.periods.where((p) => p.year == year));

  List<String> yearChampions(int year) {
    final board = yearWins(year);
    final max = board.isEmpty ? 0 : board.first.count;
    return max > 0 ? [for (final r in board) if (r.count == max) r.person.id] : [];
  }

  List<int> get years => (data.periods.map((p) => p.year).toSet().toList()..sort((a, b) => b - a));

  /// Year titles per person — the "Alle Jahre" board.
  List<Ranked> yearTitles() {
    final titles = <String, int>{};
    for (final y in years) {
      for (final pid in yearChampions(y)) {
        titles[pid] = (titles[pid] ?? 0) + 1;
      }
    }
    return _sorted(data.people.map((p) => Ranked(p, titles[p.id] ?? 0)));
  }

  int monthsWon(String personId, int year) =>
      data.periods.where((p) => p.year == year && periodWinners(p.id).contains(personId)).length;

  int titlesOf(String personId) {
    for (final r in yearTitles()) {
      if (r.person.id == personId) return r.count;
    }
    return 0;
  }

  int countInYear(String personId, int year) =>
      data.strikes.where((s) => s.personId == personId && period(s.periodId)?.year == year).length;

  List<Strike> personStrikes(String personId) =>
      data.strikes.where((s) => s.personId == personId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// A person's strikes grouped by period, newest period first.
  List<(Period?, List<Strike>)> breakdownByPeriod(String personId) {
    final groups = <String, List<Strike>>{};
    for (final s in personStrikes(personId)) {
      groups.putIfAbsent(s.periodId, () => []).add(s);
    }
    final out = [for (final e in groups.entries) (period(e.key), e.value)];
    out.sort((a, b) {
      final pa = a.$1, pb = b.$1;
      if (pa == null || pb == null) return pa == null ? 1 : -1;
      return _newestFirst(pa, pb);
    });
    return out;
  }
}
