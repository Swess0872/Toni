import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/settings.dart';
import 'theme.dart';
import 'widgets.dart';

void showSettings(BuildContext context) =>
    showToniSheet<void>(context, title: 'Einstellungen', builder: (_) => const SettingsForm());

/// The prototype's "Tweaks" as real per-device settings, plus the theme toggle.
class SettingsForm extends StatelessWidget {
  const SettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = context.watch<Settings>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(
        label: 'Erscheinungsbild',
        child: Seg<bool>(full: true, value: s.dark, options: const [(true, 'Dunkel'), (false, 'Hell')], onChanged: s.setDark),
      ),
      Field(
        label: 'Akzent',
        child: Wrap(spacing: 9, runSpacing: 9, children: [
          for (final e in accents.entries)
            Pressable(
              onTap: () => s.setAccent(e.key),
              semanticLabel: e.key,
              radius: BorderRadius.circular(99),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: e.value.acid,
                  shape: BoxShape.circle,
                  border: Border.all(color: s.accent == e.key ? t.text : Colors.transparent, width: 2),
                ),
                child: s.accent == e.key ? const Icon(Ic.check, size: 16, color: onAccent) : null,
              ),
            ),
        ]),
      ),
      Field(
        label: 'Headline-Schrift',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in Settings.fonts)
            Pressable(
              onTap: () => s.setFontHead(f),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: s.fontHead == f ? t.bg3 : t.bg,
                  border: Border.all(color: s.fontHead == f ? t.acid : t.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(f, style: GoogleFonts.getFont(f, fontSize: 15, fontWeight: FontWeight.w700, color: t.text)),
              ),
            ),
        ]),
      ),
      Field(
        label: 'Dichte',
        child: Seg<bool>(full: true, value: s.compact, options: const [(true, 'Kompakt'), (false, 'Normal')], onChanged: s.setCompact),
      ),
      Field(
        label: 'Strich-Darstellung',
        child: Seg<TallyMode>(
          full: true,
          value: s.tally,
          options: const [(TallyMode.roman, 'Römisch'), (TallyMode.zahl, 'Zahl'), (TallyMode.striche, 'Striche')],
          onChanged: s.setTally,
        ),
      ),
      Field(
        label: 'TV-Ansicht',
        hint: 'grosse Schrift, Fernbedienung',
        child: Seg<TvMode>(
          full: true,
          value: s.tv,
          options: const [(TvMode.auto, 'Automatisch'), (TvMode.an, 'An'), (TvMode.aus, 'Aus')],
          onChanged: s.setTv,
        ),
      ),
    ]);
  }
}
