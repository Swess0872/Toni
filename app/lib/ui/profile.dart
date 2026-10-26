import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

void showProfile(BuildContext context) =>
    showToniSheet<void>(context, title: 'Mein Profil', builder: (_) => const ProfileForm());

/// Center-crops to 256×256 and encodes as JPEG data URL, like the prototype's canvas crop.
String? cropAvatar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final square = img.copyResizeCropSquare(decoded, size: 256);
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(square, quality: 85))}';
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  (bool ok, String msg)? _msg;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final store = context.read<ToniStore>();
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (file == null || !mounted) return;
    final url = cropAvatar(await file.readAsBytes());
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bild konnte nicht gelesen werden.')));
      return;
    }
    await guarded(context, () => store.setMyAvatar(url));
  }

  Future<void> _savePassword() async {
    final error = _pw.text.length < 2
        ? 'Passwort ist zu kurz.'
        : (_pw.text != _pw2.text ? 'Die Passwörter stimmen nicht überein.' : null);
    if (error != null) {
      setState(() => _msg = (false, error));
      return;
    }
    try {
      await context.read<ToniStore>().changeMyPassword(_pw.text);
      if (!mounted) return;
      _pw.clear();
      _pw2.clear();
      setState(() => _msg = (true, 'Passwort geändert ✓'));
    } on ApiException catch (e) {
      if (mounted) setState(() => _msg = (false, e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final me = store.user;
    if (me == null) return const SizedBox();
    final person = store.sel.person(me.personId);
    void clearMsg(String _) {
      if (_msg != null) setState(() => _msg = null);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        person != null
            ? Avatar(person: person, size: 72)
            : Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: t.bg2, shape: BoxShape.circle, border: Border.all(color: t.line)),
                child: Icon(Ic.user, color: t.dim, size: 30),
              ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person?.name ?? me.username, style: t.head(size: 21)),
            Text('${me.isAdmin ? 'Admin' : 'Mitglied'} · @${me.username}', style: t.mono(size: 13)),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      if (person != null) ...[
        Field(
          label: 'Profilbild',
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            Btn(variant: BtnVariant.ghost, size: BtnSize.sm, icon: Ic.user, onPressed: _pickImage, child: const Text('Bild hochladen')),
            if (person.avatar != null)
              Btn(
                variant: BtnVariant.ghost,
                size: BtnSize.sm,
                icon: Ic.trash,
                onPressed: () => guarded(context, () => store.setMyAvatar(null)),
                child: const Text('Entfernen'),
              ),
          ]),
        ),
        Field(
          label: 'Deine Farbe',
          child: Wrap(spacing: 9, runSpacing: 9, children: [
            for (final c in palette)
              _Swatch(color: parseHex(c), on: person.color.toLowerCase() == c, onTap: () => guarded(context, () => store.setMyColor(c))),
          ]),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: DashedBorder(
            color: t.line2,
            child: Container(
              padding: const EdgeInsets.all(11),
              color: t.bg,
              child: Text(
                'Dieser Zugang ist keiner Person zugeordnet — Farbe und Bild kann nur eine zugeordnete Person setzen.',
                style: t.body(size: 13, color: t.dim),
              ),
            ),
          ),
        ),
      Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Field(
              label: 'Passwort ändern',
              child: TextField(
                controller: _pw,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: clearMsg,
                decoration: const InputDecoration(hintText: 'Neues Passwort'),
              ),
            ),
            TextField(
              controller: _pw2,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: clearMsg,
              onSubmitted: (_) => _savePassword(),
              decoration: const InputDecoration(hintText: 'Wiederholen'),
            ),
            const SizedBox(height: 12),
            if (_msg case (final ok, final msg))
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (ok ? ToniTheme.ja : ToniTheme.nein).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(msg, textAlign: TextAlign.center, style: t.body(size: 13, weight: FontWeight.w600, color: ok ? t.jaText : t.neinText)),
              ),
            Btn(full: true, onPressed: _savePassword, child: const Text('Passwort speichern')),
          ]),
        ),
      ),
    ]);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.on, required this.onTap});

  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hoverable(
      onTap: onTap,
      radius: BorderRadius.circular(99),
      builder: (context, hovered) => AnimatedScale(
        scale: hovered ? 1.1 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: on ? t.text : Colors.transparent, width: 2),
            boxShadow: on ? [BoxShadow(color: t.bg1, spreadRadius: 2), BoxShadow(color: color, spreadRadius: 4)] : null,
          ),
          child: on ? const Icon(Ic.check, size: 16, color: onAccent) : null,
        ),
      ),
    );
  }
}
