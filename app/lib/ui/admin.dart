import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'layout.dart';
import 'theme.dart';
import 'widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _tab = 'personen';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    const tabs = [('personen', 'Personen & Logins'), ('perioden', 'Perioden'), ('aktionen', 'Aktionen')];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: t.bg1, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(13)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (key, label) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Pressable(
                  onTap: () => setState(() => _tab = key),
                  radius: BorderRadius.circular(9),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: _tab == key ? t.acid : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                    child: Text(label, style: t.head(size: 15, weight: FontWeight.w600, color: _tab == key ? onAccent : t.dim)),
                  ),
                ),
              ),
          ]),
        ),
      ),
      switch (_tab) {
        'perioden' => const _PeriodsAdmin(),
        'aktionen' => const _ActionsAdmin(),
        _ => const _PeopleAdmin(),
      },
    ]);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.desc, required this.action, required this.child});

  final String title;
  final String desc;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: t.head(size: 19)),
            const SizedBox(height: 2),
            Text(desc, style: t.body(size: 14, color: t.dim)),
          ]),
          action,
        ]),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }
}

/// Text field that saves when it loses focus or on enter (prototype: save on blur).
class _InlineEdit extends StatefulWidget {
  const _InlineEdit({required this.value, required this.onSave, this.style, this.plain = false});

  final String value;
  final ValueChanged<String> onSave;
  final TextStyle? style;
  final bool plain;

  @override
  State<_InlineEdit> createState() => _InlineEditState();
}

class _InlineEditState extends State<_InlineEdit> {
  late final _c = TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode()..addListener(() {
      if (!_focus.hasFocus) _save();
    });

  void _save() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      _c.text = widget.value;
    } else if (v != widget.value) {
      widget.onSave(v);
    }
  }

  @override
  void didUpdateWidget(_InlineEdit old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return TextField(
      controller: _c,
      focusNode: _focus,
      style: widget.style,
      onSubmitted: (_) => _save(),
      decoration: widget.plain
          ? InputDecoration(
              isDense: true,
              filled: _focus.hasFocus,
              fillColor: t.bg2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            )
          : const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
    );
  }
}

Widget _smallInput(TextEditingController c, String hint, {bool obscure = false, double? width}) => SizedBox(
      width: width,
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
      ),
    );

// ---- Personen + Logins -------------------------------------------------------

class _PeopleAdmin extends StatefulWidget {
  const _PeopleAdmin();

  @override
  State<_PeopleAdmin> createState() => _PeopleAdminState();
}

class _PeopleAdminState extends State<_PeopleAdmin> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (await guarded(context, () => context.read<ToniStore>().addPerson(name))) _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ToniStore>();
    final phone = formFactorOf(context) == FormFactor.phone;
    return _Section(
      title: 'Personen & Logins',
      desc: 'Wer Striche bekommt — und wer sich anmelden darf.',
      action: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: phone ? 170 : 200,
          child: TextField(
            controller: _name,
            onSubmitted: (_) => _add(),
            decoration: const InputDecoration(hintText: 'Neue Person…', contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
          ),
        ),
        const SizedBox(width: 7),
        Btn(size: BtnSize.sm, icon: Ic.plus, onPressed: _add, child: const Text('Person')),
      ]),
      child: ShowMore(
        total: store.data.people.length,
        builder: (context, visible) => Column(children: [
          for (final p in store.data.people.take(visible))
            Padding(padding: const EdgeInsets.only(bottom: 11), child: _PersonCard(key: ValueKey(p.id), person: p)),
        ]),
      ),
    );
  }
}

class _PersonCard extends StatefulWidget {
  const _PersonCard({super.key, required this.person});

  final Person person;

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  bool _adding = false;
  String _role = 'mitglied';
  final _user = TextEditingController();
  final _pw = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _createLogin() async {
    if (_user.text.trim().isEmpty || _pw.text.isEmpty) return;
    final store = context.read<ToniStore>();
    if (await guarded(context, () => store.addAccount(widget.person.id, _user.text.trim(), _pw.text, _role))) {
      setState(() {
        _adding = false;
        _role = 'mitglied';
      });
      _user.clear();
      _pw.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final p = widget.person;
    final acc = store.accountFor(p.id);
    final year = store.sel.currentYear;

    return Opacity(
      opacity: p.active ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Avatar(person: p, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: _InlineEdit(
                value: p.name,
                plain: true,
                style: t.head(size: 16),
                onSave: (v) => guarded(context, () => store.updatePerson(p.id, name: v)),
              ),
            ),
            Text('${store.sel.countInYear(p.id, year)} Striche $year', style: t.mono(size: 12)),
            IconBtn(
              icon: Ic.power,
              tooltip: p.active ? 'Deaktivieren' : 'Aktivieren',
              onPressed: () => guarded(context, () => store.updatePerson(p.id, active: !p.active)),
            ),
            IconBtn(
              icon: Ic.trash,
              danger: true,
              tooltip: 'Person löschen',
              onPressed: () async {
                if (await confirmAction(context, '${p.name}, alle Striche und Login löschen?') && context.mounted) {
                  await guarded(context, () => store.removePerson(p.id));
                }
              },
            ),
          ]),
          const SizedBox(height: 10),
          DashedTop(color: t.line),
          const SizedBox(height: 11),
          if (acc != null)
            _LoginRow(account: acc, personName: p.name)
          else if (_adding)
            Wrap(spacing: 9, runSpacing: 9, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _smallInput(_user, 'Benutzername', width: 150),
              _smallInput(_pw, 'Passwort', width: 150),
              _RoleToggle(value: _role, onChanged: (r) => setState(() => _role = r)),
              Btn(size: BtnSize.sm, onPressed: _createLogin, child: const Text('Login anlegen')),
              IconBtn(icon: Ic.close, small: true, tooltip: 'Abbrechen', onPressed: () => setState(() => _adding = false)),
            ])
          else
            Align(
              alignment: Alignment.centerLeft,
              child: DashedButton(
                onPressed: () => setState(() => _adding = true),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Ic.plus),
                  const SizedBox(width: 6),
                  Text('Login für ${p.name} anlegen'),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Dashed separator line (CSS `border-top: 1px dashed`).
class DashedTop extends StatelessWidget {
  const DashedTop({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => Row(children: [
          for (var i = 0; i < c.maxWidth ~/ 7; i++) ...[
            Container(width: 4, height: 1, color: color),
            const SizedBox(width: 3),
          ],
        ]),
      );
}

class _LoginRow extends StatefulWidget {
  const _LoginRow({required this.account, required this.personName});

  final AppUser account;
  final String personName;

  @override
  State<_LoginRow> createState() => _LoginRowState();
}

class _LoginRowState extends State<_LoginRow> {
  final _pw = TextEditingController();

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.read<ToniStore>();
    final acc = widget.account;
    final admin = acc.isAdmin;

    Widget labeled(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: t.mono(size: 10, color: t.dim2, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          child,
        ]);

    return Wrap(spacing: 9, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: admin ? t.acid.withValues(alpha: 0.18) : t.bg2, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(admin ? Ic.lock : Ic.user, size: 12, color: admin ? t.acidText : t.dim),
          const SizedBox(width: 5),
          Text(admin ? 'ADMIN' : 'MITGLIED', style: t.head(size: 11, color: admin ? t.acidText : t.dim)),
        ]),
      ),
      labeled(
        'Benutzer',
        SizedBox(
          width: 140,
          child: _InlineEdit(value: acc.username, onSave: (v) => guarded(context, () => store.updateUser(acc.id, username: v))),
        ),
      ),
      labeled(
        'Neues Passwort',
        Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 130,
            child: TextField(
              controller: _pw,
              obscureText: true,
              style: t.mono(size: 14, color: t.text),
              decoration: const InputDecoration(hintText: '••••', contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
            ),
          ),
          IconBtn(
            icon: Ic.check,
            small: true,
            tooltip: 'Passwort setzen',
            onPressed: () async {
              if (_pw.text.isEmpty) return;
              if (await guarded(context, () => store.updateUser(acc.id, password: _pw.text)) && context.mounted) {
                _pw.clear();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwort für ${widget.personName} gesetzt ✓')));
              }
            },
          ),
        ]),
      ),
      labeled('Rolle', _RoleToggle(value: acc.role, onChanged: (r) => guarded(context, () => store.updateUser(acc.id, role: r)))),
      IconBtn(
        icon: Ic.trash,
        small: true,
        danger: true,
        tooltip: 'Login entfernen',
        onPressed: () async {
          if (await confirmAction(context, 'Login von ${widget.personName} entfernen?', confirmLabel: 'Entfernen') && context.mounted) {
            await guarded(context, () => store.removeUser(acc.id));
          }
        },
      ),
    ]);
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) =>
      Seg<String>(mini: true, value: value, options: const [('mitglied', 'Mitglied'), ('admin', 'Admin')], onChanged: onChanged);
}

// ---- Perioden & Anlässe -----------------------------------------------------

class _PeriodsAdmin extends StatefulWidget {
  const _PeriodsAdmin();

  @override
  State<_PeriodsAdmin> createState() => _PeriodsAdminState();
}

class _PeriodsAdminState extends State<_PeriodsAdmin> {
  String _mode = 'monat';
  int _month = DateTime.now().month - 1;
  final _year = TextEditingController(text: '${DateTime.now().year}');
  final _label = TextEditingController();
  String? _start;
  String? _end;

  @override
  void dispose() {
    _year.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final store = context.read<ToniStore>();
    final year = int.tryParse(_year.text) ?? DateTime.now().year;
    if (_mode == 'monat') {
      await guarded(context, () => store.addMonth(_month, year));
    } else if (_label.text.trim().isNotEmpty) {
      if (await guarded(context, () => store.addFreitext(_label.text.trim(), year, _start, _end))) {
        setState(() {
          _label.clear();
          _start = null;
          _end = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    return _Section(
      title: 'Perioden & Anlässe',
      desc: 'Zeiträume, in denen Striche zählen — jeweils mit Start- und Enddatum.',
      action: Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Seg<String>(mini: true, value: _mode, options: const [('monat', 'Monat'), ('freitext', 'Anlass')], onChanged: (v) => setState(() => _mode = v)),
        if (_mode == 'monat') ...[
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              initialValue: _month,
              isExpanded: true,
              dropdownColor: t.bg1,
              icon: Icon(Ic.chevron, color: t.dim),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
              items: [for (var i = 0; i < 12; i++) DropdownMenuItem(value: i, child: Text(monthsDe[i]))],
              onChanged: (v) => setState(() => _month = v ?? _month),
            ),
          ),
          _smallInput(_year, 'Jahr', width: 84),
        ] else ...[
          _smallInput(_label, 'Anlass-Name…', width: 170),
          _DateButton(value: _start, hint: 'von', onPicked: (v) => setState(() => _start = v)),
          _DateButton(value: _end, hint: 'bis', onPicked: (v) => setState(() => _end = v)),
        ],
        Btn(size: BtnSize.sm, icon: Ic.plus, onPressed: _add),
      ]),
      child: Column(children: [
        for (final p in store.sel.periodsNewestFirst()) Padding(padding: const EdgeInsets.only(bottom: 8), child: _PeriodRow(period: p)),
      ]),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period});

  final Period period;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.read<ToniStore>();
    final live = store.sel.live(period);
    final ft = period.isFreitext;
    final content = Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: live ? Color.lerp(t.bg, t.acid, 0.08) : t.bg,
        border: ft && !live ? null : Border.all(color: live ? t.acid : t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (ft) ...[Icon(Ic.bolt, size: 14, color: t.magentaText), const SizedBox(width: 8)],
            Text(periodLabel(period), style: t.head(size: 15, weight: FontWeight.w600)),
            if (live) ...[const SizedBox(width: 8), const LiveTag()],
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _DateButton(value: period.start, hint: 'von', onPicked: (v) => guarded(context, () => store.updatePeriod(period.id, start: v))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('–', style: TextStyle(color: t.dim2))),
          _DateButton(value: period.end, hint: 'bis', onPicked: (v) => guarded(context, () => store.updatePeriod(period.id, end: v))),
          const SizedBox(width: 4),
          IconBtn(
            icon: Ic.trash,
            small: true,
            danger: true,
            tooltip: 'Löschen',
            onPressed: () async {
              if (await confirmAction(context, '${periodLabel(period)} mit allen Strichen löschen?') && context.mounted) {
                await guarded(context, () => store.removePeriod(period.id));
              }
            },
          ),
        ]),
      ]),
    );
    return ft && !live ? DashedBorder(color: t.line, radius: 12, child: content) : content;
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.value, required this.hint, required this.onPicked});

  final String? value;
  final String hint;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final d = parseIsoDate(value);
    return Hoverable(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: d ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: hint == 'von' ? 'Startdatum' : 'Enddatum',
        );
        if (picked != null) onPicked(isoDate(picked));
      },
      radius: BorderRadius.circular(9),
      builder: (context, hovered) => Container(
        constraints: const BoxConstraints(minHeight: 40, minWidth: 110),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: t.bg,
          border: Border.all(color: hovered ? t.line2 : t.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          d == null ? hint : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
          style: t.mono(size: 12, color: d == null ? t.dim2 : t.text),
        ),
      ),
    );
  }
}

// ---- Aktionen ---------------------------------------------------------------

class _ActionsAdmin extends StatefulWidget {
  const _ActionsAdmin();

  @override
  State<_ActionsAdmin> createState() => _ActionsAdminState();
}

class _ActionsAdminState extends State<_ActionsAdmin> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final sel = store.sel;
    var strikes = [...store.data.strikes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_filter != 'all') strikes = strikes.where((s) => s.periodId == _filter).toList();

    return _Section(
      title: 'Aktionen',
      desc: 'Alle eingetragenen Striche — bearbeiten oder entfernen.',
      action: SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          initialValue: _filter,
          isExpanded: true,
          dropdownColor: t.bg1,
          icon: Icon(Ic.chevron, color: t.dim),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('Alle Zeiträume')),
            for (final p in sel.periodsNewestFirst()) DropdownMenuItem(value: p.id, child: Text(periodLabel(p), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _filter = v ?? 'all'),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460),
        child: strikes.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(30),
                child: Text('Keine Striche in diesem Filter.', textAlign: TextAlign.center, style: t.head(size: 15, weight: FontWeight.w500, color: t.dim)),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: strikes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (context, i) {
                  final s = strikes[i];
                  final p = sel.person(s.personId);
                  return Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Avatar(person: p, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(p?.name ?? '—', style: t.body(size: 14, weight: FontWeight.w600, color: p?.c)),
                            Text(periodLabel(sel.period(s.periodId)), style: t.mono(size: 11, color: t.dim2)),
                            if (s.viaVote) ToniBadge.vote(context),
                          ]),
                          const SizedBox(height: 1),
                          Text(s.reason, style: t.body(size: 13.5, color: t.dim)),
                        ]),
                      ),
                      IconBtn(
                        icon: Ic.trash,
                        danger: true,
                        tooltip: 'Strich entfernen',
                        onPressed: () => guarded(context, () => store.removeStrike(s.id)),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
