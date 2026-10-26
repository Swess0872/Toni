import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

void showLogin(BuildContext context, {String? reason}) =>
    showToniSheet<void>(context, title: 'Anmelden', builder: (_) => LoginForm(reason: reason));

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.reason});

  final String? reason;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _user = TextEditingController();
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await context.read<ToniStore>().login(_user.text, _pw.text);
      if (mounted) Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final demos = context.watch<ToniStore>().demoLogins;
    void clearError(String _) {
      if (_error != null) setState(() => _error = null);
    }

    return AutofillGroup(
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: t.bg2, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(16)),
          child: Icon(Ic.lock, size: 24, color: t.acidText),
        ),
        if (widget.reason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(widget.reason!, textAlign: TextAlign.center, style: t.body(size: 14, color: t.dim)),
          ),
        Field(
          label: 'Benutzername',
          child: TextField(
            controller: _user,
            autofocus: true,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            onChanged: clearError,
            decoration: const InputDecoration(hintText: 'z.B. max'),
          ),
        ),
        Field(
          label: 'Passwort',
          child: TextField(
            controller: _pw,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onChanged: clearError,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: '••••••••'),
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: ToniTheme.nein.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
            child: Text(_error!, textAlign: TextAlign.center, style: t.body(size: 13, weight: FontWeight.w600, color: t.neinText)),
          ),
        Btn(size: BtnSize.lg, full: true, onPressed: _busy ? null : _submit, child: const Text('Anmelden')),
        if (demos.isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(color: t.line, height: 1),
          const SizedBox(height: 16),
          Text('Demo-Zugänge:', style: t.mono(size: 12, color: t.dim2)),
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 7, alignment: WrapAlignment.center, children: [
            for (final d in demos)
              Hoverable(
                onTap: () => setState(() {
                  _user.text = d.username;
                  _pw.text = d.password;
                  _error = null;
                }),
                radius: BorderRadius.circular(8),
                builder: (context, hovered) => Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.bg2,
                    border: Border.all(color: hovered ? t.acid : t.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${d.username}${d.role == 'admin' ? ' ★' : ''}', style: t.mono(size: 13, color: hovered ? t.acidText : t.dim)),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}
