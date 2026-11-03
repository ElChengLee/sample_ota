import 'package:app_theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'mini_native.dart';

/// Chạy độc lập: `flutter run` trong mini_apps/mini_native (Android hoặc iOS).
/// Khi nằm trong Shell, file này không được dùng: Shell tự dựng [MiniNativeApp].
void main() => runApp(const StandaloneApp());

class StandaloneApp extends StatefulWidget {
  const StandaloneApp({super.key});

  @override
  State<StandaloneApp> createState() => _StandaloneAppState();
}

class _StandaloneAppState extends State<StandaloneApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _theme = ThemeController();
  late final _host = StandaloneHost(_messengerKey, _navigatorKey);

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeSpec>(
      valueListenable: _theme,
      builder: (context, spec, _) => MaterialApp(
        title: 'Mini Native',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light(spec),
        darkTheme: AppTheme.dark(spec),
        themeMode: spec.mode,
        home: MiniNativeApp(host: _host),
      ),
    );
  }
}
