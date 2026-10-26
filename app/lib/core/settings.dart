import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TallyMode { roman, zahl, striche }

enum TvMode { auto, an, aus }

/// Per-device preferences (the prototype's "Tweaks"), persisted locally.
class Settings extends ChangeNotifier {
  Settings(this._prefs) {
    dark = _prefs.getString('toni_theme') != 'light';
    accent = _prefs.getString('toni_accent') ?? 'lime';
    fontHead = _prefs.getString('toni_font_head') ?? 'Space Grotesk';
    compact = _prefs.getBool('toni_compact') ?? false;
    tally = TallyMode.values.asNameMap()[_prefs.getString('toni_tally')] ?? TallyMode.roman;
    tv = TvMode.values.asNameMap()[_prefs.getString('toni_tv')] ?? TvMode.auto;
  }

  static const fonts = ['Space Grotesk', 'Archivo Black', 'Syne', 'Bricolage Grotesque'];

  final SharedPreferences _prefs;

  late bool dark;
  late String accent;
  late String fontHead;
  late bool compact;
  late TallyMode tally;
  late TvMode tv;

  void setDark(bool v) {
    dark = v;
    _prefs.setString('toni_theme', v ? 'dark' : 'light');
    notifyListeners();
  }

  void setAccent(String v) {
    accent = v;
    _prefs.setString('toni_accent', v);
    notifyListeners();
  }

  void setFontHead(String v) {
    fontHead = v;
    _prefs.setString('toni_font_head', v);
    notifyListeners();
  }

  void setCompact(bool v) {
    compact = v;
    _prefs.setBool('toni_compact', v);
    notifyListeners();
  }

  void setTally(TallyMode v) {
    tally = v;
    _prefs.setString('toni_tally', v.name);
    notifyListeners();
  }

  void setTv(TvMode v) {
    tv = v;
    _prefs.setString('toni_tv', v.name);
    notifyListeners();
  }
}
