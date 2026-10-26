import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/settings.dart';

const accents = {
  'lime': (acid: Color(0xFFA3E635), amber: Color(0xFFF59E0B), magenta: Color(0xFFF472B6)),
  'cyan': (acid: Color(0xFF22D3EE), amber: Color(0xFFFBBF24), magenta: Color(0xFFF472B6)),
  'magenta': (acid: Color(0xFFF472B6), amber: Color(0xFFF59E0B), magenta: Color(0xFFA3E635)),
  'violet': (acid: Color(0xFFC084FC), amber: Color(0xFFFBBF24), magenta: Color(0xFF22D3EE)),
};

/// Text on accent-filled surfaces stays dark in both themes.
const onAccent = Color(0xFF0C0D10);

// Neutrals from the spec (oklch, hue 265) converted to sRGB.
const _dark = (
  bg: Color(0xFF0C0E14), bg1: Color(0xFF14171E), bg2: Color(0xFF1C2029), bg3: Color(0xFF282D36),
  line: Color(0xFF333842), line2: Color(0xFF484D58),
  text: Color(0xFFF0F2F4), dim: Color(0xFFA1A5AC), dim2: Color(0xFF70747D),
);
const _light = (
  bg: Color(0xFFFAFCFF), bg1: Color(0xFFF5F7FB), bg2: Color(0xFFECEEF4), bg3: Color(0xFFE0E3EA),
  line: Color(0xFFD4D7E0), line2: Color(0xFFBFC4CF),
  text: Color(0xFF181F2E), dim: Color(0xFF4F5562), dim2: Color(0xFF757A85),
);

/// All design tokens. Components read colors only from here, never hardcoded neutrals.
class ToniTheme extends ThemeExtension<ToniTheme> {
  ToniTheme({
    required this.isDark,
    required this.bg,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.line2,
    required this.text,
    required this.dim,
    required this.dim2,
    required this.acid,
    required this.amber,
    required this.magenta,
    required this.fontHead,
    required this.compact,
    required this.tally,
    required this.tv,
  });

  final bool isDark;
  final Color bg, bg1, bg2, bg3, line, line2, text, dim, dim2;
  final Color acid, amber, magenta;
  final String fontHead;
  final bool compact;
  final TallyMode tally;
  final bool tv;

  static const ja = Color(0xFF34D399);
  static const nein = Color(0xFFFB7185);
  static const rank2 = Color(0xFFBEC4D2);
  static const rank3 = Color(0xFFBC8C71);

  double get pad => compact ? 16 : 22;
  double get r => compact ? 13 : 16;

  /// Accent used as text/icon color: darkened in light mode for contrast.
  Color get acidText => isDark ? acid : Color.lerp(acid, Colors.black, 0.3)!;
  Color get amberText => isDark ? amber : Color.lerp(amber, Colors.black, 0.25)!;
  Color get magentaText => isDark ? magenta : Color.lerp(magenta, Colors.black, 0.25)!;
  Color get jaText => isDark ? ja : Color.lerp(ja, Colors.black, 0.35)!;
  Color get neinText => isDark ? nein : Color.lerp(nein, Colors.black, 0.2)!;

  /// Accent glow in dark mode, soft neutral drop shadow in light mode.
  List<BoxShadow> glow(Color c, {double blur = 18, double alpha = 0.3, double dy = 4}) => isDark
      ? [BoxShadow(color: c.withValues(alpha: alpha), blurRadius: blur, offset: Offset(0, dy))]
      : [
          BoxShadow(color: c.withValues(alpha: alpha * 0.45), blurRadius: blur, offset: Offset(0, dy)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ];

  List<BoxShadow> get cardShadow =>
      isDark ? const [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3))];

  TextStyle head({double size = 16, FontWeight weight = FontWeight.w700, Color? color}) => GoogleFonts.getFont(
        fontHead,
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        letterSpacing: -0.01 * size,
        height: 1.2,
      );

  TextStyle body({double size = 15, FontWeight weight = FontWeight.w400, Color? color, FontStyle? style, double height = 1.5}) =>
      GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: weight, color: color ?? text, fontStyle: style, height: height);

  TextStyle mono({double size = 12, FontWeight weight = FontWeight.w400, Color? color, double letterSpacing = 0}) =>
      GoogleFonts.spaceMono(fontSize: size, fontWeight: weight, color: color ?? dim, letterSpacing: letterSpacing, height: 1.3);

  static ToniTheme of(BuildContext context) => Theme.of(context).extension<ToniTheme>()!;

  @override
  ToniTheme copyWith() => this;

  @override
  ToniTheme lerp(ToniTheme? other, double t) => t < 0.5 || other == null ? this : other;
}

extension ToniThemeContext on BuildContext {
  ToniTheme get t => ToniTheme.of(this);
}

ThemeData buildTheme(Settings s, {required bool tv}) {
  final n = s.dark ? _dark : _light;
  final a = accents[s.accent] ?? accents['lime']!;
  final tokens = ToniTheme(
    isDark: s.dark,
    bg: n.bg, bg1: n.bg1, bg2: n.bg2, bg3: n.bg3, line: n.line, line2: n.line2,
    text: n.text, dim: n.dim, dim2: n.dim2,
    acid: a.acid, amber: a.amber, magenta: a.magenta,
    fontHead: s.fontHead, compact: s.compact, tally: s.tally, tv: tv,
  );
  final brightness = s.dark ? Brightness.dark : Brightness.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  OutlineInputBorder border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c));

  return base.copyWith(
    scaffoldBackgroundColor: n.bg,
    canvasColor: n.bg1,
    colorScheme: ColorScheme.fromSeed(seedColor: a.acid, brightness: brightness).copyWith(
      primary: a.acid,
      onPrimary: onAccent,
      surface: n.bg1,
      onSurface: n.text,
      error: ToniTheme.nein,
    ),
    // google_fonts' *TextTheme helpers return material_ui types; set the family directly instead.
    textTheme: base.textTheme.apply(fontFamily: GoogleFonts.hankenGrotesk().fontFamily, bodyColor: n.text, displayColor: n.text),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.acidText,
      selectionColor: a.acid.withValues(alpha: 0.6),
      selectionHandleColor: a.acid,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: n.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      hintStyle: TextStyle(color: n.dim2),
      border: border(n.line),
      enabledBorder: border(n.line),
      focusedBorder: border(a.acid),
      errorBorder: border(ToniTheme.nein),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: n.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: n.line)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: n.bg3,
      contentTextStyle: TextStyle(color: n.text),
      behavior: SnackBarBehavior.floating,
    ),
    focusColor: a.acid.withValues(alpha: 0.2),
    extensions: [tokens],
  );
}
