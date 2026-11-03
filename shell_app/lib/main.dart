import 'package:app_theme/app_theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'mini_app/mini_app_repository.dart';
import 'mini_app/webview_pool.dart';
import 'policy/shell_config.dart';
import 'router/app_router.dart';
import 'router/deep_link_handler.dart';
import 'shell_scope.dart';

void main() {
  final repository = MiniAppRepository(serverUrl: miniAppServerUrl, publicKey: kOtaPublicKey);
  runApp(ShellApp(
    themeController: ThemeController(),
    repository: repository,
    config: ShellConfigStore(repository: repository),
  ));
}

class ShellApp extends StatefulWidget {
  const ShellApp({super.key, required this.themeController, required this.repository, required this.config});

  final ThemeController themeController;
  final MiniAppRepository repository;
  final ShellConfigStore config;

  @override
  State<ShellApp> createState() => _ShellAppState();
}

class _ShellAppState extends State<ShellApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Router tạo một lần; không tạo trong build() vì đổi theme sẽ rebuild MaterialApp.
  late final _router = AppRouter(repository: widget.repository, shellConfig: widget.config, messengerKey: _messengerKey);
  late final _deepLinks = DeepLinkHandler(
    router: _router,
    repository: widget.repository,
    config: widget.config,
    messengerKey: _messengerKey,
  );
  late final _routerConfig = _router.config(deepLinkBuilder: _buildDeepLink);
  final _webViews = WebViewPool();

  /// Quay lại app (từ nền) thì làm mới config tổng: quyền vừa sửa trên server
  /// có hiệu lực mà không cần khởi động lại.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.config.ready.ignore();
    _lifecycle = AppLifecycleListener(onResume: () => widget.config.refresh().ignore());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Mọi link từ hệ điều hành đều giao cho [DeepLinkHandler] để qua cùng một
  /// lần kiểm tra quyền ([SystemCaller]: chỉ mở được màn `exported`).
  /// - Cold start: dựng Home trước, link được xử lý sau frame đầu nên stack
  ///   luôn là [Home, MiniApp] và Back quay về Home thay vì thoát app.
  /// - App đang chạy: link tới mini app đang mở đi qua bridge thay vì
  ///   auto_route thay route và load lại WebView.
  DeepLink _buildDeepLink(PlatformDeepLink link) {
    if (link.initial) {
      final uri = link.uri;
      if (uri.pathSegments.every((s) => s.isEmpty)) return DeepLink.defaultPath;
      WidgetsBinding.instance.addPostFrameCallback((_) => _deepLinks.open(uri, caller: const SystemCaller()));
      return const DeepLink([HomeRoute()]);
    }
    _deepLinks.open(link.uri, caller: const SystemCaller());
    return DeepLink.none;
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      repository: widget.repository,
      config: widget.config,
      webViews: _webViews,
      themeController: widget.themeController,
      messengerKey: _messengerKey,
      deepLinks: _deepLinks,
      child: ValueListenableBuilder<ThemeSpec>(
        valueListenable: widget.themeController,
        builder: (context, spec, _) => MaterialApp.router(
          title: 'Super App Shell',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          theme: AppTheme.light(spec),
          darkTheme: AppTheme.dark(spec),
          themeMode: spec.mode,
          routerConfig: _routerConfig,
        ),
      ),
    );
  }
}
