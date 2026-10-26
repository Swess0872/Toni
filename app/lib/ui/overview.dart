import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'layout.dart';
import 'person_detail.dart';
import 'theme.dart';
import 'vote_banner.dart';
import 'widgets.dart';

class Overview extends StatelessWidget {
  const Overview({super.key, required this.onRequireLogin});

  final VoidCallback onRequireLogin;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ToniStore>();
    final sel = store.sel;
    final ff = formFactorOf(context);
    final votes = sel.openVotes;

    final top = votes.isNotEmpty
        ? Column(children: [
            for (final v in votes) ...[VoteBanner(key: ValueKey(v.id), vote: v, onRequireLogin: onRequireLogin), const SizedBox(height: 14)],
          ])
        : const Padding(padding: EdgeInsets.only(bottom: 18), child: WideBoard());

    final lists = [
      for (final p in sel.livePeriods())
        RankList(
          key: ValueKey(p.id),
          title: periodLabel(p),
          sub: periodRange(p).isNotEmpty ? periodRange(p) : (p.isFreitext ? 'Anlass' : ''),
          live: sel.live(p),
          rows: sel.leaderboard(PeriodScope(p.id)),
          scope: PeriodScope(p.id),
        ),
    ];

    final hint = Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        'Tipp: Auf einen Namen tippen zeigt, woraus sich die Striche zusammensetzen.',
        textAlign: TextAlign.center,
        style: context.t.mono(size: 12.5, color: context.t.dim2),
      ),
    );

    if (ff == FormFactor.tv) {
      // Wall display: live votes / podium on the left, all live rankings on the right.
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: top),
        const SizedBox(width: 20),
        Expanded(flex: 7, child: _Grid(columns: lists.length > 1 ? 2 : 1, children: lists)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      top,
      _Grid(columns: ff == FormFactor.desktop ? 3 : 1, children: lists),
      hint,
    ]);
  }
}

/// Fixed-column grid whose rows size to their tallest child (CSS grid, align-items: start).
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    if (columns == 1) {
      return Column(children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: gap), children[i]],
      ]);
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var j = 0; j < columns; j++) ...[
            if (j > 0) const SizedBox(width: gap),
            Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
          ],
        ]),
      ));
    }
    return Column(children: rows);
  }
}

// ---- Rotating podium --------------------------------------------------------

class WideBoard extends StatefulWidget {
  const WideBoard({super.key});

  @override
  State<WideBoard> createState() => _WideBoardState();
}

class _WideBoardState extends State<WideBoard> {
  int _idx = 0;
  bool _hovered = false;
  bool _focused = false;
  DateTime _touchedUntil = DateTime(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final paused = _hovered || _focused || DateTime.now().isBefore(_touchedUntil) || reducedMotion(context);
      if (!paused && mounted) setState(() => _idx = (_idx + 1) % 2);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sel = context.watch<ToniStore>().sel;
    final year = sel.currentYear;
    final List<({String key, String title, String sub, List<Ranked> rows, Scope scope})> views = [
      (key: 'jahr', title: 'Jahr $year', sub: 'Monatssiege — wer führt die Saison an', rows: sel.yearWins(year), scope: YearScope(year)),
      (key: 'alle', title: 'Alle Jahre', sub: 'Jahressiege — die ewige Hall of Shame', rows: sel.yearTitles(), scope: const AllScope()),
    ];
    final v = views[_idx];
    void pick(Person p) => showPersonDetail(context, p, v.scope);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => _focused = f,
        child: Listener(
          onPointerDown: (_) => _touchedUntil = DateTime.now().add(const Duration(seconds: 12)),
          child: Panel(
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.title, style: t.head(size: 19)),
                    const SizedBox(height: 3),
                    Text(v.sub, style: t.body(size: 12.5, color: t.dim)),
                  ]),
                ),
                for (var i = 0; i < views.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Pressable(
                      onTap: () => setState(() => _idx = i),
                      semanticLabel: views[i].title,
                      radius: BorderRadius.circular(99),
                      child: Padding(
                        // Bigger hit area than the 6px dot.
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _idx ? 30 : 22,
                          height: 6,
                          decoration: BoxDecoration(color: i == _idx ? t.acid : t.bg3, borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: const Cubic(.2, .9, .25, 1),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim), child: child),
                ),
                child: Column(key: ValueKey(v.key), children: [
                  Podium(rows: v.rows, onPick: pick),
                  if (v.rows.length > 3)
                    Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                      for (var i = 3; i < v.rows.length; i++) _RestChip(rank: i + 1, row: v.rows[i], onTap: () => pick(v.rows[i].person)),
                    ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class Podium extends StatelessWidget {
  const Podium({super.key, required this.rows, required this.onPick});

  final List<Ranked> rows;
  final ValueChanged<Person> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final top = rows.where((r) => r.count > 0).take(3).toList();
    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Noch keine Siege vergeben — alles offen.', textAlign: TextAlign.center, style: t.head(size: 16, weight: FontWeight.w500, color: t.dim)),
      );
    }
    final order = [if (top.length > 1) top[1], top[0], if (top.length > 2) top[2]];
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final r in order)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: _Pod(rank: top.indexOf(r) + 1, row: r, onTap: () => onPick(r.person)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pod extends StatelessWidget {
  const _Pod({required this.rank, required this.row, required this.onTap});

  final int rank;
  final Ranked row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final first = rank == 1;
    return Hoverable(
      onTap: onTap,
      semanticLabel: '${row.person.name}, Platz $rank',
      radius: BorderRadius.circular(12),
      builder: (context, hovered) => AnimatedSlide(
        offset: Offset(0, hovered ? -0.02 : 0),
        duration: const Duration(milliseconds: 120),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Avatar(person: row.person, size: first ? 64 : 52),
          const SizedBox(height: 5),
          Text(row.person.name, style: t.head(size: 14, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Tally(count: row.count, big: first, color: first ? t.amberText : t.text),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: switch (rank) { 1 => 92.0, 2 => 64.0, _ => 46.0 },
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: first ? t.amber.withValues(alpha: 0.4) : t.line),
              color: first ? null : t.bg2,
              gradient: first
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(t.bg2, t.amber, 0.3)!, t.bg2],
                    )
                  : null,
            ),
            child: Text(
              '$rank',
              style: t.head(size: 30, color: first ? t.amberText : t.dim2).copyWith(
                    shadows: first ? [Shadow(color: t.amber.withValues(alpha: 0.5), blurRadius: 20)] : null,
                  ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RestChip extends StatelessWidget {
  const _RestChip({required this.rank, required this.row, required this.onTap});

  final int rank;
  final Ranked row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hoverable(
      onTap: onTap,
      radius: BorderRadius.circular(99),
      builder: (context, hovered) => Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.fromLTRB(8, 5, 13, 5),
        decoration: BoxDecoration(
          color: t.bg,
          border: Border.all(color: hovered ? t.line2 : t.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$rank', style: t.mono(size: 12, weight: FontWeight.w700, color: t.dim2)),
          const SizedBox(width: 8),
          Avatar(person: row.person, size: 26),
          const SizedBox(width: 8),
          Text(row.person.name, style: t.body(size: 14, weight: FontWeight.w600)),
          const SizedBox(width: 8),
          Tally(count: row.count),
        ]),
      ),
    );
  }
}

// ---- Ranking per live period ------------------------------------------------

class RankList extends StatelessWidget {
  const RankList({super.key, required this.title, required this.sub, required this.live, required this.rows, required this.scope});

  final String title;
  final String sub;
  final bool live;
  final List<Ranked> rows;
  final Scope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final max = rows.fold(1, (m, r) => r.count > m ? r.count : m);
    final total = rows.fold(0, (s, r) => s + r.count);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(title, style: t.head(size: 16)),
                if (live) const LiveTag(),
              ]),
              if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, style: t.mono(size: 11.5))),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$total', style: t.head(size: 24, color: t.amberText).copyWith(height: 1)),
            const SizedBox(height: 2),
            Text('STRICHE', style: t.body(size: 10, weight: FontWeight.w500, color: t.dim2).copyWith(letterSpacing: 0.4)),
          ]),
        ]),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _RankRow(rank: i + 1, row: rows[i], max: max, crown: i == 0, onTap: () => showPersonDetail(context, rows[i].person, scope)),
          ),
      ]),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row, required this.max, required this.crown, required this.onTap});

  final int rank;
  final Ranked row;
  final int max;
  final bool crown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final rankColor = switch (rank) { 1 => t.amberText, 2 => ToniTheme.rank2, 3 => ToniTheme.rank3, _ => t.dim2 };
    return Hoverable(
      onTap: onTap,
      semanticLabel: '${row.person.name}: ${row.count} Striche',
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(color: hovered ? t.bg2 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          SizedBox(width: 22, child: Text('$rank', textAlign: TextAlign.center, style: t.mono(size: 15, weight: FontWeight.w700, color: rankColor))),
          const SizedBox(width: 12),
          Avatar(person: row.person, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: row.person.name),
                      if (crown && row.count > 0) TextSpan(text: '  ★', style: TextStyle(color: t.amberText, fontSize: 12)),
                    ]),
                    style: t.body(size: 15, weight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Tally(count: row.count),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 5,
                  color: t.bg3,
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    curve: const Cubic(.2, .8, .2, 1),
                    widthFactor: max > 0 ? row.count / max : 0,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(color: row.person.c.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 4),
          AnimatedOpacity(
            opacity: hovered ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Icon(Ic.chevronR, size: 17, color: t.dim2),
          ),
        ]),
      ),
    );
  }
}
