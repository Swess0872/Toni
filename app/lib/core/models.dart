import 'dart:ui';

Color parseHex(String hex) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xa3e635;
  return Color(0xFF000000 | v);
}

const palette = [
  '#a3e635', '#f59e0b', '#f472b6', '#38bdf8', '#c084fc', '#fb7185', '#34d399', '#fbbf24',
];

class Person {
  Person({required this.id, required this.name, required this.active, required this.color, this.avatar});

  final String id;
  final String name;
  final bool active;
  final String color;
  /// 256×256 JPEG as data URL.
  final String? avatar;

  Color get c => parseHex(color);

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id'] as String,
        name: j['name'] as String,
        active: j['active'] as bool,
        color: j['color'] as String,
        avatar: j['avatar'] as String?,
      );
}

class Period {
  Period({
    required this.id,
    required this.type,
    required this.year,
    this.month,
    this.label,
    this.start,
    this.end,
    this.active = true,
  });

  final String id;
  /// "monat" or "freitext".
  final String type;
  final int year;
  /// 0-based (Januar = 0), months only.
  final int? month;
  /// Occasions only.
  final String? label;
  /// ISO "YYYY-MM-DD".
  final String? start;
  final String? end;
  final bool active;

  bool get isMonat => type == 'monat';
  bool get isFreitext => type == 'freitext';

  factory Period.fromJson(Map<String, dynamic> j) => Period(
        id: j['id'] as String,
        type: j['type'] as String,
        year: j['year'] as int,
        month: j['month'] as int?,
        label: j['label'] as String?,
        start: j['start'] as String?,
        end: j['end'] as String?,
        active: j['active'] as bool? ?? true,
      );
}

class Strike {
  Strike({
    required this.id,
    required this.personId,
    required this.periodId,
    required this.reason,
    required this.createdAt,
    required this.source,
  });

  final String id;
  final String personId;
  final String periodId;
  final String reason;
  final DateTime createdAt;
  /// "direkt" or "abstimmung".
  final String source;

  bool get viaVote => source == 'abstimmung';

  factory Strike.fromJson(Map<String, dynamic> j) => Strike(
        id: j['id'] as String,
        personId: j['personId'] as String,
        periodId: j['periodId'] as String,
        reason: j['reason'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        source: j['source'] as String,
      );
}

class Vote {
  Vote({
    required this.id,
    required this.personId,
    required this.periodId,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
    required this.status,
    required this.ballots,
  });

  final String id;
  final String personId;
  final String periodId;
  final String reason;
  final String? createdBy;
  final DateTime createdAt;
  final String status;
  /// personId → "ja" | "nein".
  final Map<String, String> ballots;

  int get ja => ballots.values.where((b) => b == 'ja').length;
  int get nein => ballots.values.where((b) => b == 'nein').length;

  factory Vote.fromJson(Map<String, dynamic> j) => Vote(
        id: j['id'] as String,
        personId: j['personId'] as String,
        periodId: j['periodId'] as String,
        reason: j['reason'] as String,
        createdBy: j['createdBy'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: j['status'] as String,
        ballots: (j['ballots'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      );
}

class AppUser {
  AppUser({required this.id, required this.username, required this.role, this.personId});

  final String id;
  final String username;
  /// "admin" or "mitglied".
  final String role;
  final String? personId;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        username: j['username'] as String,
        role: j['role'] as String,
        personId: j['personId'] as String?,
      );
}

class DemoLogin {
  DemoLogin(this.username, this.password, this.role);
  final String username;
  final String password;
  final String role;
}

class ToniData {
  const ToniData({this.people = const [], this.periods = const [], this.strikes = const [], this.votes = const []});

  final List<Person> people;
  final List<Period> periods;
  final List<Strike> strikes;
  final List<Vote> votes;

  factory ToniData.fromJson(Map<String, dynamic> j) => ToniData(
        people: [for (final p in j['people'] as List) Person.fromJson(p as Map<String, dynamic>)],
        periods: [for (final p in j['periods'] as List) Period.fromJson(p as Map<String, dynamic>)],
        strikes: [for (final s in j['strikes'] as List) Strike.fromJson(s as Map<String, dynamic>)],
        votes: [for (final v in j['votes'] as List) Vote.fromJson(v as Map<String, dynamic>)],
      );
}

/// What a person breakdown or leaderboard is counted over.
sealed class Scope {
  const Scope();
}

class PeriodScope extends Scope {
  const PeriodScope(this.periodId);
  final String periodId;
}

class YearScope extends Scope {
  const YearScope(this.year);
  final int year;
}

class AllScope extends Scope {
  const AllScope();
}

class Ranked {
  const Ranked(this.person, this.count);
  final Person person;
  final int count;
}
