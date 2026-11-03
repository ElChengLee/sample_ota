import 'package:app_theme/app_theme.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import 'router/app_router.dart';
import 'state/cart_controller.dart';

/// Dependency dùng chung của mini app. Page do auto_route tạo từ URL (chỉ nhận
/// path param), nên service lấy qua scope này thay vì biến global.
class ShopScope extends InheritedWidget {
  const ShopScope({super.key, required this.shell, required this.cart, required super.child});

  final ShellApi shell;
  final CartController cart;

  static ShopScope of(BuildContext context) => _check(context.dependOnInheritedWidgetOfExactType<ShopScope>());

  /// Không đăng ký phụ thuộc: dùng trong event handler, `initState`.
  static ShopScope read(BuildContext context) => _check(context.getInheritedWidgetOfExactType<ShopScope>());

  static ShopScope _check(ShopScope? scope) {
    assert(scope != null, 'ShopScope không có trong cây widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(ShopScope oldWidget) => shell != oldWidget.shell || cart != oldWidget.cart;
}

/// Kết quả handshake với Shell. Có sẵn cho mọi page (kể cả page mở thẳng qua
/// deep link) vì [MiniShopApp] chỉ dựng router sau khi handshake xong.
class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});

  final MiniAppContext session;

  static MiniAppContext of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope không có trong cây widget');
    return scope!.session;
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) => session != oldWidget.session;
}

class MiniShopApp extends StatefulWidget {
  const MiniShopApp({super.key, required this.shell, required this.router, required this.cart});

  final ShellApi shell;
  final AppRouter router;
  final CartController cart;

  @override
  State<MiniShopApp> createState() => _MiniShopAppState();
}

class _MiniShopAppState extends State<MiniShopApp> {
  // Tạo một lần: build() chạy lại mỗi khi đổi theme.
  late final _routerConfig = widget.router.config(deepLinkBuilder: widget.router.buildDeepLink);
  late Future<MiniAppContext> _session = widget.shell.init();

  @override
  Widget build(BuildContext context) {
    return ShopScope(
      shell: widget.shell,
      cart: widget.cart,
      // Theme do Shell điều khiển: Shell đổi mode/brand thì app rebuild.
      child: ValueListenableBuilder<ThemeSpec>(
        valueListenable: widget.shell.theme,
        builder: (context, spec, _) => MaterialApp.router(
          title: 'Mini Shop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(spec),
          darkTheme: AppTheme.dark(spec),
          themeMode: spec.mode,
          routerConfig: _routerConfig,
          builder: (context, child) => FutureBuilder<MiniAppContext>(
            future: _session,
            builder: (context, snapshot) => switch (snapshot) {
              AsyncSnapshot(:final data?) => SessionScope(session: data, child: child!),
              AsyncSnapshot(:final error?) => Scaffold(
                  body: DsEmptyState(
                    icon: Icons.link_off,
                    message: 'Không kết nối được Shell\n$error',
                    action: DsButton(
                      label: 'Thử lại',
                      onPressed: () => setState(() {
                        _session = widget.shell.init();
                      }),
                    ),
                  ),
                ),
              _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
            },
          ),
        ),
      ),
    );
  }
}
