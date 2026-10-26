import 'models.dart';

const monthsDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

// Same abbreviations as toLocaleDateString('de-DE', {month: 'short'}).
const _monthsShortDe = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
];

String toRoman(int n) {
  if (n < 1) return '—';
  const map = [
    ('M', 1000), ('CM', 900), ('D', 500), ('CD', 400), ('C', 100), ('XC', 90),
    ('L', 50), ('XL', 40), ('X', 10), ('IX', 9), ('V', 5), ('IV', 4), ('I', 1),
  ];
  final out = StringBuffer();
  var rest = n;
  for (final (sym, val) in map) {
    while (rest >= val) {
      out.write(sym);
      rest -= val;
    }
  }
  return out.toString();
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String? s) => s == null ? null : DateTime.tryParse(s);

String periodLabel(Period? p) {
  if (p == null) return '—';
  return p.isFreitext ? (p.label ?? '—') : '${monthsDe[p.month ?? 0]} ${p.year}';
}

String periodRange(Period? p) {
  final s = parseIsoDate(p?.start), e = parseIsoDate(p?.end);
  if (s == null || e == null) return '';
  return '${s.day}. ${_monthsShortDe[s.month - 1]} – ${e.day}. ${_monthsShortDe[e.month - 1]} ${e.year}';
}

bool isPeriodLive(Period? p, [DateTime? now]) {
  if (p == null || p.start == null || p.end == null) return false;
  final t = isoDate(now ?? DateTime.now());
  return p.start!.compareTo(t) <= 0 && t.compareTo(p.end!) <= 0;
}

String timeAgo(DateTime at, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(at).inSeconds;
  if (d < 60) return 'gerade eben';
  if (d < 3600) return 'vor ${d ~/ 60} Min';
  if (d < 86400) return 'vor ${d ~/ 3600} Std';
  final days = d ~/ 86400;
  if (days < 30) return 'vor $days ${days == 1 ? 'Tag' : 'Tagen'}';
  final l = at.toLocal();
  return '${l.day.toString().padLeft(2, '0')}. ${_monthsShortDe[l.month - 1]}';
}
