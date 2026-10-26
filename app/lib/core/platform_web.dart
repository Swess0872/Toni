import 'package:web/web.dart' as web;

final _tvAgents = RegExp(
  r'smart-?tv|tizen|web0s|webos|netcast|bravia|hbbtv|vidaa|crkey|googletv|android tv|aftb|aftm|aftt|aftmm|\btv\b',
  caseSensitive: false,
);

bool isTvBrowser() => _tvAgents.hasMatch(web.window.navigator.userAgent);
