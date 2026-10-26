import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Live vote card, tinted with the target person's color.
class VoteBanner extends StatelessWidget {
  const VoteBanner({super.key, required this.vote, required this.onRequireLogin});

  final Vote vote;
  final VoidCallback onRequireLogin;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final sel = store.sel;
    final target = sel.person(vote.personId);
    final author = sel.person(vote.createdBy);
    final period = sel.period(vote.periodId);
    final vb = target?.c ?? t.magenta;
    final ja = vote.ja, nein = vote.nein;
    final voted = vote.ballots.length;
    final myVote = store.myPersonId == null ? null : vote.ballots[store.myPersonId];
    final leading = ja > nein ? 'ja' : (nein > ja ? 'nein' : 'tie');

    Future<void> cast(String choice) async {
      if (!store.isLoggedIn) {
        onRequireLogin();
        return;
      }
      if (store.myPersonId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dieser Zugang ist keiner Person zugeordnet und kann nicht abstimmen.')),
        );
        return;
      }
      await guarded(context, () => store.castVote(vote.id, choice));
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reducedMotion(context) ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: const Cubic(.2, .9, .25, 1),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, -10 * (1 - v)), child: Transform.scale(scale: 0.98 + 0.02 * v, child: child)),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.r),
          border: Border.all(color: Color.lerp(t.line, vb, 0.45)!),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.6],
            colors: [Color.lerp(t.bg1, vb, 0.16)!, t.bg1],
          ),
          boxShadow: t.cardShadow,
        ),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -1.4),
                  radius: 1.1,
                  colors: [vb.withValues(alpha: 0.28), vb.withValues(alpha: 0)],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(t.pad),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(alignment: WrapAlignment.spaceBetween, spacing: 10, runSpacing: 4, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  LiveDot(color: vb),
                  const SizedBox(width: 8),
                  Text('ABSTIMMUNG LÄUFT', style: t.head(size: 13, color: t.isDark ? vb : Color.lerp(vb, Colors.black, 0.35)).copyWith(letterSpacing: 0.8)),
                ]),
                Text('$voted/${sel.activePeople.length} abgestimmt · ${timeAgo(vote.createdAt)}', style: t.mono(size: 12)),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Avatar(person: target, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Strich für '),
                        TextSpan(text: target?.name ?? '—', style: TextStyle(color: vb)),
                        const TextSpan(text: '?'),
                      ]),
                      style: t.head(size: MediaQuery.sizeOf(context).width < 560 ? 18 : 21),
                    ),
                    const SizedBox(height: 7),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (period != null) _VChip(periodLabel(period), tint: vb),
                      _VChip('vorgeschlagen von ${author?.name ?? '—'}'),
                    ]),
                    const SizedBox(height: 9),
                    Text('„${vote.reason}"', style: t.body(size: 15, style: FontStyle.italic, height: 1.45)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              _VoteBar(ja: ja, nein: nein),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(children: [
                  Text('Ja $ja', style: t.mono(size: 13, weight: FontWeight.w700, color: t.jaText)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(color: t.bg2, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      switch (leading) { 'ja' => 'STRICH FÜHRT', 'nein' => 'FREISPRUCH FÜHRT', _ => 'UNENTSCHIEDEN' },
                      style: t.mono(
                        size: 11,
                        color: switch (leading) { 'ja' => t.jaText, 'nein' => t.neinText, _ => t.dim },
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('Nein $nein', style: t.mono(size: 13, weight: FontWeight.w700, color: t.neinText)),
                ]),
              ),
              if (store.isLoggedIn) ...[
                Row(children: [
                  Expanded(
                    child: Btn(
                      variant: myVote == 'nein' ? BtnVariant.neinOn : BtnVariant.nein,
                      icon: Ic.close,
                      full: true,
                      onPressed: store.offline ? null : () => cast('nein'),
                      child: const Text('Freispruch'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Btn(
                      variant: myVote == 'ja' ? BtnVariant.jaOn : BtnVariant.ja,
                      icon: Ic.bolt,
                      full: true,
                      onPressed: store.offline ? null : () => cast('ja'),
                      child: const Text('Strich!'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DashedButton(
                  full: true,
                  onPressed: voted == 0 || store.offline ? null : () => guarded(context, () => store.resolveVote(vote.id)),
                  child: const Text('Abstimmung auswerten →'),
                ),
              ] else
                Btn(variant: BtnVariant.ghost, size: BtnSize.lg, icon: Ic.lock, full: true, onPressed: onRequireLogin, child: const Text('Zum Abstimmen anmelden')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VChip extends StatelessWidget {
  const _VChip(this.label, {this.tint});

  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tint == null ? t.bg2 : Color.lerp(t.bg2, tint, 0.14),
        border: Border.all(color: tint == null ? t.line : tint!.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label, style: t.mono(size: 11)),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({required this.ja, required this.nein});

  final int ja;
  final int nein;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final total = ja + nein;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 12,
        color: t.bg3,
        child: total == 0
            ? Center(child: Text('noch keine Stimmen', style: t.mono(size: 9)))
            : LayoutBuilder(
                builder: (context, c) => Row(children: [
                  AnimatedContainer(duration: const Duration(milliseconds: 400), width: c.maxWidth * ja / total, color: ToniTheme.ja),
                  AnimatedContainer(duration: const Duration(milliseconds: 400), width: c.maxWidth * nein / total, color: ToniTheme.nein),
                ]),
              ),
      ),
    );
  }
}
