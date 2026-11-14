import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Who voted what. A running vote follows live updates; a past one is shown as passed in.
void showVoteDetail(BuildContext context, Vote vote) =>
    showToniSheet<void>(context, title: 'Wer hat wie gestimmt?', builder: (_) => _VoteDetail(vote: vote));

/// The vote a strike came from (see [Strike.viaVote]), with who voted what.
void showStrikeVote(BuildContext context, Strike strike) =>
    showToniSheet<void>(context, title: 'Wer hat wie gestimmt?', builder: (_) => _StrikeVote(strike: strike));

/// A strike does not store its vote's id; the vote is the accepted one with the
/// same person, period and reason, resolved closest to when the strike was made.
Vote? voteForStrike(Strike strike, List<Vote> votes) {
  final matches = votes
      .where((v) => v.status == 'angenommen' && v.personId == strike.personId && v.periodId == strike.periodId && v.reason == strike.reason)
      .toList();
  if (matches.isEmpty) return null;
  Duration gap(Vote v) => (v.resolvedAt ?? v.createdAt).difference(strike.createdAt).abs();
  matches.sort((a, b) => gap(a).compareTo(gap(b)));
  return matches.first;
}

class _VoteDetail extends StatelessWidget {
  const _VoteDetail({required this.vote});

  final Vote vote;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sel = context.watch<ToniStore>().sel;
    // A running vote is taken from the live state so new ballots show up immediately.
    final v = sel.openVotes.where((o) => o.id == vote.id).firstOrNull ?? vote;
    final open = v.status == 'offen';
    final ja = [for (final e in v.ballots.entries) if (e.value == 'ja') sel.person(e.key)].nonNulls.toList();
    final nein = [for (final e in v.ballots.entries) if (e.value == 'nein') sel.person(e.key)].nonNulls.toList();
    final missing = open ? sel.activePeople.where((p) => !v.ballots.containsKey(p.id)).toList() : <Person>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _VoteSummary(vote: v),
      const SizedBox(height: 18),
      _Group(label: 'Strich!', color: t.jaText, people: ja),
      _Group(label: 'Freispruch', color: t.neinText, people: nein),
      if (open) _Group(label: 'Noch nicht abgestimmt', color: t.dim, people: missing),
    ]);
  }
}

/// Target, reason, period and result of a vote.
class _VoteSummary extends StatelessWidget {
  const _VoteSummary({required this.vote});

  final Vote vote;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sel = context.watch<ToniStore>().sel;
    final target = sel.person(vote.personId);
    final (label, color) = switch (vote.status) {
      'angenommen' => ('STRICH', t.jaText),
      'abgelehnt' => ('FREISPRUCH', t.neinText),
      _ => ('LÄUFT', t.magentaText),
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Avatar(person: target, size: 40),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(target?.name ?? '—', style: t.head(size: 16))),
            ToniBadge(label, color: color.withValues(alpha: 0.16), textColor: color),
          ]),
          const SizedBox(height: 4),
          Text('„${vote.reason}"', style: t.body(size: 14, style: FontStyle.italic, height: 1.4)),
          const SizedBox(height: 5),
          Text(
            '${periodLabel(sel.period(vote.periodId))} · ${_date(vote.resolvedAt ?? vote.createdAt)} · Ja ${vote.ja} : ${vote.nein} Nein',
            style: t.mono(size: 11, color: t.dim2),
          ),
        ]),
      ),
    ]);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.color, required this.people});

  final String label;
  final Color color;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${label.toUpperCase()} · ${people.length}', style: t.mono(size: 11, weight: FontWeight.w700, color: color, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        if (people.isEmpty)
          Text('niemand', style: t.body(size: 13, color: t.dim2, style: FontStyle.italic))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in people)
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Avatar(person: p, size: 26),
                  const SizedBox(width: 8),
                  Text(p.name, style: t.body(size: 14, weight: FontWeight.w600)),
                ]),
              ),
          ]),
      ]),
    );
  }
}

class _StrikeVote extends StatefulWidget {
  const _StrikeVote({required this.strike});

  final Strike strike;

  @override
  State<_StrikeVote> createState() => _StrikeVoteState();
}

class _StrikeVoteState extends State<_StrikeVote> {
  late final Future<List<Vote>> _votes = context.read<ToniStore>().voteHistory();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _votes,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return _Empty(e is ApiException && e.offline ? 'Offline — das Ergebnis gibt es nur mit Verbindung.' : '$e');
        }
        if (!snap.hasData) {
          return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
        }
        final vote = voteForStrike(widget.strike, snap.data!);
        if (vote == null) return const _Empty('Zu diesem Strich ist keine Abstimmung mehr gespeichert.');
        return _VoteDetail(vote: vote);
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        child: Text(text, textAlign: TextAlign.center, style: context.t.body(size: 14, color: context.t.dim)),
      );
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year}';
}
