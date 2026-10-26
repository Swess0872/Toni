import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'layout.dart';
import 'theme.dart';
import 'widgets.dart';

void showAddStrike(BuildContext context) =>
    showToniSheet<void>(context, title: 'Neuer Toni-Strich', builder: (_) => const AddStrikeForm());

class AddStrikeForm extends StatefulWidget {
  const AddStrikeForm({super.key});

  @override
  State<AddStrikeForm> createState() => _AddStrikeFormState();
}

class _AddStrikeFormState extends State<AddStrikeForm> {
  String? _personId;
  String? _periodId;
  final _reason = TextEditingController();
  String? _flash;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  List<Period> _options(ToniStore store) {
    final live = store.data.periods.where(store.sel.live).toList()
      ..sort((a, b) {
        final t = (a.isMonat ? 0 : 1) - (b.isMonat ? 0 : 1);
        return t != 0 ? t : (a.start ?? '').compareTo(b.start ?? '');
      });
    if (live.isNotEmpty) return live;
    final cp = store.sel.currentPeriod;
    return cp == null ? [] : [cp];
  }

  Future<void> _submit(bool vote) async {
    final store = context.read<ToniStore>();
    setState(() => _busy = true);
    final ok = await guarded(context, () async {
      final reason = _reason.text.trim();
      if (vote) {
        await store.startVote(_personId!, _periodId!, reason);
      } else {
        await store.addStrike(_personId!, _periodId!, reason);
      }
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _flash = vote ? 'abstimmung' : 'eingetragen';
    });
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final opts = _options(store);
    if (_periodId == null || !opts.any((p) => p.id == _periodId)) _periodId = opts.isEmpty ? null : opts.first.id;
    final valid = _personId != null && _periodId != null && _reason.text.trim().length > 2 && !_busy;
    final phone = formFactorOf(context) == FormFactor.phone;

    if (_flash != null) return _Flash(vote: _flash == 'abstimmung');

    Widget step(int n, Widget field) => phone
        ? field
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 0, right: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.bg2, shape: BoxShape.circle, border: Border.all(color: t.line)),
              child: Text('$n', style: t.mono(size: 13, weight: FontWeight.w700)),
            ),
            Expanded(child: field),
          ]);

    final actions = [
      Btn(variant: BtnVariant.ghost, size: BtnSize.lg, full: true, icon: Ic.bolt, onPressed: valid ? () => _submit(true) : null, child: const Text('Abstimmung starten')),
      Btn(variant: BtnVariant.primary, size: BtnSize.lg, full: true, icon: Ic.check, onPressed: valid ? () => _submit(false) : null, child: const Text('Direkt eintragen')),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      step(
        1,
        Field(
          label: 'Wer hat Mist gebaut?',
          child: LayoutBuilder(builder: (context, c) {
            final cols = ((c.maxWidth + 8) / (96 + 8)).floor().clamp(1, 6);
            final w = (c.maxWidth - 8 * (cols - 1)) / cols;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in store.sel.activePeople) SizedBox(width: w, child: _NameChip(person: p, on: _personId == p.id, onTap: () => setState(() => _personId = p.id))),
            ]);
          }),
        ),
      ),
      step(
        2,
        Field(
          label: 'Wann?',
          hint: 'nur laufende Zeiträume',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: _periodId,
              isExpanded: true,
              dropdownColor: t.bg1,
              borderRadius: BorderRadius.circular(11),
              icon: Icon(Ic.chevron, color: t.dim),
              style: t.body(size: 14, weight: FontWeight.w500),
              items: [
                for (final p in opts)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text('${periodLabel(p)}${periodRange(p).isNotEmpty ? ' · ${periodRange(p)}' : ''}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _periodId = v),
            ),
            if (opts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Aktuell läuft kein Zeitraum — im Admin anlegen.', textAlign: TextAlign.right, style: t.mono(size: 11, color: t.dim2)),
              ),
          ]),
        ),
      ),
      step(
        3,
        Field(
          label: 'Was ist passiert?',
          hint: 'ehrlich & gnadenlos',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 140,
              style: t.body(size: 15),
              decoration: const InputDecoration(hintText: 'z.B. Hat den Abwasch 5 Tage stehen lassen…', counterText: ''),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${_reason.text.length}/140', textAlign: TextAlign.right, style: t.mono(size: 11, color: t.dim2)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      if (MediaQuery.sizeOf(context).width < 420)
        Column(children: [actions[0], const SizedBox(height: 11), actions[1]])
      else
        Row(children: [Expanded(child: actions[0]), const SizedBox(width: 11), Expanded(child: actions[1])]),
      const SizedBox(height: 12),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Bei '),
          TextSpan(text: 'Abstimmung', style: TextStyle(color: t.magentaText, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' entscheidet ihr per einfacher Mehrheit (mehr Ja als Nein).'),
        ]),
        textAlign: TextAlign.center,
        style: t.body(size: 12.5, color: t.dim),
      ),
    ]);
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip({required this.person, required this.on, required this.onTap});

  final Person person;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hoverable(
      onTap: onTap,
      semanticLabel: person.name,
      radius: BorderRadius.circular(11),
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: on ? t.bg2 : t.bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: on ? person.c : (hovered ? t.line2 : t.line), width: on ? 2 : 1),
        ),
        child: Row(children: [
          Avatar(person: person, size: 30),
          const SizedBox(width: 8),
          Expanded(child: Text(person.name, overflow: TextOverflow.ellipsis, style: t.body(size: 14, weight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _Flash extends StatelessWidget {
  const _Flash({required this.vote});

  final bool vote;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = vote ? t.magenta : t.acid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: const Cubic(.2, 1.4, .4, 1),
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(vote ? Ic.bolt : Ic.check, size: 34, color: vote ? t.magentaText : t.acidText),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            vote ? 'Abstimmung gestartet — sie läuft jetzt auf der Übersicht.' : 'Strich eingetragen. Glückwunsch zur Schande.',
            textAlign: TextAlign.center,
            style: t.head(size: 16, weight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
