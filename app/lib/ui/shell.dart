import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import 'add_strike.dart';
import 'admin.dart';
import 'layout.dart';
import 'login.dart';
import 'overview.dart';
import 'profile.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

enum AppRoute { overview, admin }

/// App frame: sticky translucent header, the two routes, and the add FAB.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  AppRoute _route = AppRoute.overview;

  // TV: the header hides after a few seconds without input and comes back on any key or pointer.
  static const _tvHeaderTimeout = Duration(seconds: 4);
  bool _headerShown = true;
  Timer? _hideTimer;
  final _headerFocus = FocusNode(skipTraversal: true, canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _hideTimer?.cancel();
    _headerFocus.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _showHeader();
    return false;
  }

  void _showHeader() {
    if (!context.t.tv) return;
    if (!_headerShown) setState(() => _headerShown = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(_tvHeaderTimeout, () {
      if (!mounted) return;
      // Keep it while the remote's focus is inside the header.
      if (_headerFocus.hasFocus) return _showHeader();
      setState(() => _headerShown = false);
    });
  }

  void _requireLogin([String? reason]) => showLogin(context, reason: reason ?? 'Bitte melde dich an, um fortzufahren.');

  void _add() {
    if (context.read<ToniStore>().isLoggedIn) {
      showAddStrike(context);
    } else {
      _requireLogin('Nur angemeldete Mitglieder können Striche eintragen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final ff = formFactorOf(context);
    final headerHeight = 62.0 + MediaQuery.paddingOf(context).top;
    final tv = ff == FormFactor.tv;
    final headerVisible = !tv || _headerShown;
    if (tv && _hideTimer == null) WidgetsBinding.instance.addPostFrameCallback((_) => _showHeader());

    final Widget page;
    if (!store.loaded) {
      page = const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()));
    } else if (_route == AppRoute.admin) {
      page = store.isAdmin ? const AdminDashboard() : _Gate(onLogin: () => _requireLogin('Melde dich mit einem Admin-Zugang an.'), onBack: () => setState(() => _route = AppRoute.overview));
    } else {
      page = Overview(onRequireLogin: () => _requireLogin('Nur angemeldete Mitglieder können abstimmen.'));
    }

    final scaffold = Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerHeight),
        child: AnimatedSlide(
          offset: headerVisible ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: Focus(
            focusNode: _headerFocus,
            child: _Header(
              route: _route,
              onRoute: (r) => setState(() => _route = r),
              onAdd: _add,
              onLogin: () => showLogin(context),
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.2),
            radius: 1.2,
            colors: [t.acid.withValues(alpha: t.isDark ? 0.07 : 0.03), t.acid.withValues(alpha: 0)],
            stops: const [0, 0.6],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: store.refresh,
          edgeOffset: headerHeight,
          // Content moves up into the space of the hidden TV header.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: headerVisible ? headerHeight : 0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, top, child) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(t.pad, top + t.pad, t.pad, (tv ? t.pad : 120) + MediaQuery.paddingOf(context).bottom),
              child: child,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tv ? double.infinity : maxContentWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (store.offline) _OfflineBanner(asOf: store.dataAsOf),
                  if (store.connectionError != null) _ErrorBanner(message: store.connectionError!),
                  page,
                ]),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _route == AppRoute.overview && store.isLoggedIn && !store.offline && !tv ? _Fab(onTap: _add) : null,
    );

    if (!tv) return scaffold;
    return Listener(
      onPointerHover: (_) => _showHeader(),
      onPointerDown: (_) => _showHeader(),
      child: scaffold,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.route, required this.onRoute, required this.onAdd, required this.onLogin});

  final AppRoute route;
  final ValueChanged<AppRoute> onRoute;
  final VoidCallback onAdd;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = context.watch<ToniStore>();
    final ff = formFactorOf(context);
    final narrow = ff == FormFactor.phone;
    final me = store.user;
    final mePerson = store.sel.person(me?.personId);

    Widget navLink(AppRoute r, String label, {bool lock = false}) {
      final on = route == r;
      return Hoverable(
        onTap: () => onRoute(r),
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 40),
          padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? t.bg2 : (hovered ? t.bg1 : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (lock) ...[Icon(Ic.lock, size: 14, color: on || hovered ? t.text : t.dim), const SizedBox(width: 6)],
            Text(label, style: t.body(size: narrow ? 14 : 15, weight: FontWeight.w600, color: on || hovered ? t.text : t.dim)),
          ]),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.82),
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ff == FormFactor.tv ? double.infinity : maxContentWidth + 2 * t.pad),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.pad, vertical: 12),
                  child: Row(children: [
                    Pressable(
                      onTap: () => onRoute(AppRoute.overview),
                      semanticLabel: 'Toni — Übersicht',
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Transform.rotate(
                          angle: -0.07,
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.acid,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [BoxShadow(color: t.acid.withValues(alpha: t.isDark ? 0.45 : 0.3), blurRadius: 22)],
                            ),
                            child: Text('T', style: t.head(size: 22, color: onAccent)),
                          ),
                        ),
                        if (MediaQuery.sizeOf(context).width >= 400 || !store.isLoggedIn) ...[
                          const SizedBox(width: 10),
                          Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'TONI'),
                              TextSpan(text: 'strich', style: TextStyle(color: t.dim2, fontWeight: FontWeight.w500)),
                            ]),
                            style: t.head(size: narrow ? 18 : 21).copyWith(letterSpacing: 0.4, height: 1),
                          ),
                        ],
                      ]),
                    ),
                    SizedBox(width: narrow ? 6 : 18),
                    if (!narrow) ...[
                      navLink(AppRoute.overview, 'Übersicht'),
                      const SizedBox(width: 4),
                      navLink(AppRoute.admin, 'Admin', lock: !store.isAdmin),
                    ],
                    const Spacer(),
                    if (narrow) ...[
                      IconBtn(
                        icon: route == AppRoute.admin ? Icons.leaderboard_outlined : Ic.lock,
                        tooltip: route == AppRoute.admin ? 'Übersicht' : 'Admin',
                        onPressed: () => onRoute(route == AppRoute.admin ? AppRoute.overview : AppRoute.admin),
                      ),
                    ],
                    IconBtn(icon: Ic.settings, tooltip: 'Einstellungen', onPressed: () => showSettings(context)),
                    const SizedBox(width: 6),
                    if (me != null) ...[
                      Btn(
                        size: BtnSize.sm,
                        icon: Ic.plus,
                        onPressed: store.offline ? null : onAdd,
                        child: narrow ? null : const Text('Strich'),
                      ),
                      SizedBox(width: narrow ? 6 : 14),
                      Hoverable(
                        onTap: () => showProfile(context),
                        semanticLabel: 'Mein Profil',
                        builder: (context, hovered) => Container(
                          padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
                          decoration: BoxDecoration(color: hovered ? t.bg1 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            mePerson != null
                                ? Avatar(person: mePerson, size: 32)
                                : Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(color: t.bg2, shape: BoxShape.circle, border: Border.all(color: t.line)),
                                    child: Icon(Ic.user, size: 16, color: t.dim),
                                  ),
                            if (!narrow) ...[
                              const SizedBox(width: 9),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text('${me.username}${me.isAdmin ? ' · Admin' : ''}', style: t.head(size: 13, weight: FontWeight.w600)),
                                Text('Profil bearbeiten', style: t.mono(size: 10.5, color: hovered ? t.acidText : t.dim2)),
                              ]),
                            ],
                          ]),
                        ),
                      ),
                      IconBtn(icon: Ic.power, tooltip: 'Abmelden', onPressed: store.logout),
                    ] else
                      Btn(variant: BtnVariant.ghost, size: BtnSize.sm, icon: Ic.user, onPressed: onLogin, child: const Text('Anmelden')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: 'Strich hinzufügen',
      radius: BorderRadius.circular(20),
      onHover: (v) => setState(() => _hovered = v),
      child: AnimatedRotation(
        turns: _hovered ? 0.25 : 0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedScale(
          scale: _hovered ? 1.06 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: t.acid,
              borderRadius: BorderRadius.circular(20),
              boxShadow: t.glow(t.acid, blur: 30, alpha: 0.45, dy: 8),
            ),
            child: const Icon(Ic.plus, size: 28, color: onAccent),
          ),
        ),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.onLogin, required this.onBack});

  final VoidCallback onLogin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final loggedIn = context.watch<ToniStore>().isLoggedIn;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 40),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(color: t.bg1, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.r)),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(color: t.bg2, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(18)),
            child: Icon(Ic.lock, size: 28, color: t.amberText),
          ),
          Text('Admin-Bereich', style: t.head(size: 23)),
          const SizedBox(height: 8),
          Text(
            loggedIn
                ? 'Dein Zugang hat keine Admin-Rechte. Frag einen Admin, dich freizuschalten.'
                : 'Bitte melde dich mit einem Admin-Zugang an.',
            textAlign: TextAlign.center,
            style: t.body(size: 15, color: t.dim, height: 1.55),
          ),
          const SizedBox(height: 22),
          loggedIn
              ? Btn(variant: BtnVariant.ghost, size: BtnSize.lg, onPressed: onBack, child: const Text('← zurück zur Übersicht'))
              : Btn(size: BtnSize.lg, onPressed: onLogin, child: const Text('Anmelden')),
        ]),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ToniTheme.nein.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(message, textAlign: TextAlign.center, style: t.body(size: 13, weight: FontWeight.w600, color: t.neinText)),
    );
  }
}

/// Shown while the server is unreachable: what you see is the last saved copy.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.asOf});

  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: t.amber.withValues(alpha: 0.14),
        border: Border.all(color: t.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, size: 20, color: t.amberText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Offline — nur Ansicht', style: t.head(size: 14, color: t.amberText)),
            const SizedBox(height: 2),
            Text(
              asOf == null
                  ? 'Noch keine gespeicherten Daten. Toni verbindet sich automatisch, sobald das Netz zurück ist.'
                  : 'Stand von ${_formatAsOf(asOf!)}. Toni verbindet sich automatisch, sobald das Netz zurück ist.',
              style: t.body(size: 12.5, color: t.dim, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }

  static String _formatAsOf(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final time = '${two(d.hour)}:${two(d.minute)}';
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay ? 'heute $time' : '${two(d.day)}.${two(d.month)}. $time';
  }
}
