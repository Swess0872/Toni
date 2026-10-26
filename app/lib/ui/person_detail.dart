import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'layout.dart';
import 'theme.dart';
import 'widgets.dart';

void showPersonDetail(BuildContext context, Person person, Scope scope) {
  final sel = context.read<ToniStore>().sel;
  final label = switch (scope) {
    PeriodScope(:final periodId) => periodLabel(sel.period(periodId)),
    YearScope(:final year) => 'Jahr $year',
    AllScope() => 'Alle Jahre',
  };
  showToniSheet<void>(
    context,
    title: 'Aufschlüsselung · $label',
    builder: (_) => PersonDetail(personId: person.id, scope: scope, scopeLabel: label),
  );
}

class PersonDetail extends StatelessWidget {
  const PersonDetail({super.key, required this.personId, required this.scope, required this.scopeLabel});

  final String personId;
  final Scope scope;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sel = context.watch<ToniStore>().sel;
    final person = sel.person(personId);
    if (person == null) return const SizedBox();

    var groups = sel.breakdownByPeriod(person.id);
    groups = switch (scope) {
      PeriodScope(:final periodId) => groups.where((g) => g.$1?.id == periodId).toList(),
      YearScope(:final year) => groups.where((g) => g.$1?.year == year).toList(),
      AllScope() => groups,
    };
    final total = groups.fold(0, (n, g) => n + g.$2.length);
    final year = sel.currentYear;
    final phone = formFactorOf(context) == FormFactor.phone;

    final stats = [
      _Stat(k: scopeLabel, v: total, l: 'Striche'),
      _Stat(k: 'Monatssiege $year', v: sel.monthsWon(person.id, year), l: 'gewonnene Perioden'),
      _Stat(k: 'Jahressiege', v: sel.titlesOf(person.id), l: 'gewonnene Jahre'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Avatar(person: person, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person.name, style: t.head(size: 22)),
            Text('$total ${total == 1 ? 'Strich' : 'Striche'} · $scopeLabel', style: t.body(size: 13, color: t.dim)),
          ]),
        ),
        Tally(count: total, big: true, color: person.c),
      ]),
      const SizedBox(height: 18),
      if (phone)
        for (final s in stats) Padding(padding: const EdgeInsets.only(bottom: 9), child: s)
      else
        Row(children: [
          for (var i = 0; i < stats.length; i++) ...[if (i > 0) const SizedBox(width: 9), Expanded(child: stats[i])],
        ]),
      SizedBox(height: phone ? 11 : 20),
      if (total == 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
          child: Text('Keine Striche in diesem Zeitraum.', textAlign: TextAlign.center, style: t.head(size: 15, weight: FontWeight.w500, color: t.dim)),
        )
      else
        for (final (period, strikes) in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.only(bottom: 7),
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Wrap(spacing: 9, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (period?.isFreitext ?? false) ...[Icon(Ic.bolt, size: 13, color: t.magentaText), const SizedBox(width: 6)],
                        Text(periodLabel(period), style: t.head(size: 15, weight: FontWeight.w600)),
                      ]),
                      if (periodRange(period).isNotEmpty) Text(periodRange(period), style: t.mono(size: 11, color: t.dim2)),
                      if (period != null && sel.periodWinners(period.id).contains(person.id)) ToniBadge.won(context),
                    ]),
                  ),
                  Text('${strikes.length}×', style: t.mono(size: 13, weight: FontWeight.w700, color: t.amberText)),
                ]),
              ),
              for (final s in strikes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 7, right: 10),
                      decoration: BoxDecoration(color: person.c, shape: BoxShape.circle),
                    ),
                    Expanded(child: Text(s.reason, style: t.body(size: 14, height: 1.45))),
                    if (s.viaVote) Padding(padding: const EdgeInsets.only(left: 8), child: ToniBadge.vote(context)),
                  ]),
                ),
            ]),
          ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.k, required this.v, required this.l});

  final String k;
  final int v;
  final String l;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(k.toUpperCase(), textAlign: TextAlign.center, style: t.mono(size: 11, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text('$v', style: t.head(size: 28)),
        const SizedBox(height: 1),
        Text(l, textAlign: TextAlign.center, style: t.body(size: 10, color: t.dim2)),
      ]),
    );
  }
}
