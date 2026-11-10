import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import 'mini_app_models.dart';
import 'mini_app_repository.dart';

/// Cài (nếu chưa có hoặc có bản mới) rồi push `MiniAppRoute`.
///
/// Cờ chống bấm đôi nằm ở caller: hàm này await tới khi mini app đóng.
Future<void> installAndOpenMiniApp(
  BuildContext context, {
  required MiniAppListing listing,
  required MiniAppRepository repository,
  required void Function(double progress) onProgress,
  required void Function() onFinished,
  required Future<void> Function() refresh,
}) async {
  var installed = listing.installed;
  try {
    if (listing.remote != null &&
        (listing.needsDownload || listing.hasUpdate)) {
      if (context.mounted) onProgress(0);
      installed = await repository.install(
        listing.remote!,
        onProgress: (progress) {
          if (context.mounted) onProgress(progress);
        },
      );
    }
  } on Object catch (e) {
    debugPrint('[MiniApp] install ${listing.info.id} failed: $e');
    final message = e is MiniAppInstallException
        ? e.message
        : 'Không tải được mini app, kiểm tra kết nối mạng.';
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tải thất bại: $message')));
    }
    return;
  } finally {
    if (context.mounted) onFinished();
  }

  if (!context.mounted || installed == null) return;
  await refresh();
  if (!context.mounted) return;
  // Future của push hoàn tất khi mini app đóng.
  await context.router.push(MiniAppRoute(appId: installed.info.id));
}
