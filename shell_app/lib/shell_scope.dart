import 'package:app_theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'mini_app/mini_app_repository.dart';
import 'mini_app/webview_pool.dart';
import 'policy/shell_config.dart';
import 'router/deep_link_handler.dart';

/// Dependency dùng chung cho các page. Page do auto_route khởi tạo từ route
/// (chỉ nhận path/query param), nên service được lấy qua scope này thay vì constructor.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.repository,
    required this.config,
    required this.webViews,
    required this.themeController,
    required this.messengerKey,
    required this.deepLinks,
    required super.child,
  });

  /// Mở [SuperAppLinks] từ bất kỳ đâu trong Shell (Home, bridge của mini app).
  final DeepLinkHandler deepLinks;

  final MiniAppRepository repository;

  /// Config tổng (quyền, điều hướng chéo, tạm khoá) do server phát hành.
  final ShellConfigStore config;

  /// WebView tạo sẵn cho lần mở mini app tiếp theo.
  final WebViewPool webViews;
  final ThemeController themeController;

  /// Cho phép hiện SnackBar từ nơi không có BuildContext (vd route guard).
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  /// Đọc không đăng ký phụ thuộc, dùng được trong `initState`.
  static ShellScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope không có trong cây widget');
    return scope!;
  }

  static ShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope không có trong cây widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      repository != oldWidget.repository || config != oldWidget.config || themeController != oldWidget.themeController;
}
