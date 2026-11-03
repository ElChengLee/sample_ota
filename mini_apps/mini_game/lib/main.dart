import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'memory_game_page.dart';
import 'shell_bridge.dart';

/// Script build truyền vào qua `--dart-define=APP_VERSION=...`.
const kBuildVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

final navigatorKey = GlobalKey<NavigatorState>();

/// Giá trị đầu đọc từ query `?mode=&brand=` để frame đầu đã đúng màu.
final theme = ValueNotifier(GameTheme.fromJson(Uri.base.queryParameters));

/// Tên người chơi lấy từ Shell khi handshake.
final playerName = ValueNotifier<String?>(null);

void main() {
  final bridge = ShellBridge.instance;

  // Back từ Shell: đóng dialog nếu có, trả handled=false ở màn gốc để Shell đóng mini app.
  bridge.handle('backPressed', (_) async {
    final handled = await navigatorKey.currentState?.maybePop() ?? false;
    return {'handled': handled};
  });

  // App chỉ có 1 màn: chấp nhận "/" (về màn chơi), route khác báo lỗi để Shell hiện SnackBar.
  bridge.handle('navigate', (params) async {
    final path = params['path'] as String? ?? '/';
    if (path != '/' && path.isNotEmpty) throw ArgumentError('Route không tồn tại: $path');
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    return null;
  });

  bridge.onEvent((name, data) {
    if (name == 'themeChanged') theme.value = GameTheme.fromJson(data);
  });

  bridge.init().then((result) {
    if (result['theme'] is Map) theme.value = GameTheme.fromJson((result['theme'] as Map).cast());
    if (result['user'] is Map) playerName.value = (result['user'] as Map)['name'] as String?;
  }).catchError((Object e) => debugPrint('[mini_game] init failed: $e'));

  runApp(const MiniGameApp());
}

class MiniGameApp extends StatelessWidget {
  const MiniGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameTheme>(
      valueListenable: theme,
      builder: (context, spec, _) => MaterialApp(
        title: 'Mini Game',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: spec.build(Brightness.light),
        darkTheme: spec.build(Brightness.dark),
        themeMode: spec.mode,
        home: const MemoryGamePage(),
      ),
    );
  }
}
