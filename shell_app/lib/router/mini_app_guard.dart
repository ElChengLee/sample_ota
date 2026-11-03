import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../mini_app/mini_app_repository.dart';
import '../policy/shell_config.dart';

/// Chặn vào trang mini app khi app đang tạm khoá trong config tổng, và (với
/// mini app web, khi có [repository]) khi app chưa được cài.
class MiniAppGuard extends AutoRouteGuard {
  MiniAppGuard({this.repository, required this.config, required this.messengerKey});

  /// `null`: không cần cài (mini app native biên dịch sẵn).
  final MiniAppRepository? repository;
  final ShellConfigStore config;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    final appId = resolver.route.params.getString('appId');
    await config.ready;
    final String? denied;
    if (!config.value.policyOf(appId).enabled) {
      denied = 'Mini app "$appId" đang tạm khoá.';
    } else if (repository != null && !(await repository!.installedApps()).containsKey(appId)) {
      denied = 'Mini app "$appId" chưa được cài. Hãy tải về từ màn hình chính.';
    } else {
      denied = null;
    }
    if (denied == null) {
      resolver.next();
      return;
    }
    debugPrint('[Router] chặn mở $appId: $denied');
    resolver.next(false);
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(denied)));
  }
}
