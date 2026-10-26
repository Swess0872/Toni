import 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart' as impl;

/// True when running in a smart-TV browser, or when the URL has ?tv=1.
bool detectTv() => Uri.base.queryParameters['tv'] == '1' || impl.isTvBrowser();
