import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/platform.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'ui/layout.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = ToniStore(ApiClient(apiBaseUrl()), prefs);
  store.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => Settings(prefs)),
      ChangeNotifierProvider.value(value: store),
    ],
    child: const ToniApp(),
  ));
}

class ToniApp extends StatefulWidget {
  const ToniApp({super.key});

  @override
  State<ToniApp> createState() => _ToniAppState();
}

class _ToniAppState extends State<ToniApp> {
  late final bool _tvDevice = detectTv();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Catch up on changes missed while the app was in the background.
    _lifecycle = AppLifecycleListener(onResume: () => context.read<ToniStore>().refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Settings>();
    final tv = switch (settings.tv) { TvMode.an => true, TvMode.aus => false, TvMode.auto => _tvDevice };
    return MaterialApp(
      title: 'Toni — Strichsystem',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de'),
      theme: buildTheme(settings, tv: tv),
      builder: (context, child) => tv ? _TvFrame(child: child!) : child!,
      home: const Shell(),
    );
  }
}

/// Lays the app out at [tvDesignWidth] and scales it to the screen, so it reads
/// from the couch, and lets the remote's arrow keys move focus.
class _TvFrame extends StatelessWidget {
  const _TvFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.size.width / tvDesignWidth;
    final logical = mq.size / scale;
    return Shortcuts(
      shortcuts: tvShortcuts,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: logical.width,
          height: logical.height,
          child: MediaQuery(data: mq.copyWith(size: logical), child: child),
        ),
      ),
    );
  }
}
