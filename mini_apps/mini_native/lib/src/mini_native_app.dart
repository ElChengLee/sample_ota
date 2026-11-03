import 'package:flutter/material.dart';

import 'host.dart';
import 'pages/compat_page.dart';

/// Gốc của mini app. Host chỉ cần đặt widget này vào một route.
///
/// - Không tạo `MaterialApp`: theme, locale, ScaffoldMessenger lấy từ host,
///   nên đổi theme ở Shell là mini app đổi theo ngay.
/// - Có [Navigator] riêng: route bên trong mini app không lẫn vào stack của
///   Shell. Back (nút cứng, vuốt) pop route bên trong trước, hết route mới
///   gọi [MiniNativeHost.close].
class MiniNativeApp extends StatefulWidget {
  const MiniNativeApp({super.key, required this.host});

  final MiniNativeHost host;

  @override
  State<MiniNativeApp> createState() => _MiniNativeAppState();
}

class _MiniNativeAppState extends State<MiniNativeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MiniNativeScope(
      host: widget.host,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final navigator = _navigatorKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          } else {
            widget.host.close();
          }
        },
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute(settings: settings, builder: (_) => const CompatPage()),
        ),
      ),
    );
  }
}

/// Cho các page bên trong lấy [MiniNativeHost].
class MiniNativeScope extends InheritedWidget {
  const MiniNativeScope({super.key, required this.host, required super.child});

  final MiniNativeHost host;

  static MiniNativeHost of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MiniNativeScope>();
    assert(scope != null, 'MiniNativeScope không có trong cây widget');
    return scope!.host;
  }

  @override
  bool updateShouldNotify(MiniNativeScope oldWidget) => host != oldWidget.host;
}
