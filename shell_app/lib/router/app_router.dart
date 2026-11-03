import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../mini_app/mini_app_repository.dart';
import '../policy/shell_config.dart';
import 'app_router.gr.dart';
import 'mini_app_guard.dart';

export 'app_router.gr.dart';

/// Route của Shell:
/// ```
/// /                                   HomeRoute
/// /mini-app/:appId?path=/product/p2   MiniAppRoute (guard: đã cài, không bị tạm khoá)
/// /native/:appId                      NativeMiniAppRoute (guard: không bị tạm khoá)
/// ```
/// `path` là route bên trong mini app, được chuyển tiếp cho router của mini app.
/// Mọi deep link (kể cả lúc cold start) đi qua `DeepLinkHandler` để kiểm tra quyền.
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter({required this.repository, required this.shellConfig, required this.messengerKey});

  final MiniAppRepository repository;
  final ShellConfigStore shellConfig;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: HomeRoute.page, path: '/', initial: true),
        AutoRoute(
          page: MiniAppRoute.page,
          path: '/mini-app/:appId',
          guards: [MiniAppGuard(repository: repository, config: shellConfig, messengerKey: messengerKey)],
        ),
        AutoRoute(
          page: NativeMiniAppRoute.page,
          path: '/native/:appId',
          guards: [MiniAppGuard(config: shellConfig, messengerKey: messengerKey)],
        ),
      ];
}
