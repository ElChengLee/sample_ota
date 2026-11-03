import 'package:flutter/material.dart';

/// CanvasKit dùng chung cho mọi mini app build cùng engine revision (cùng bản
/// Flutter). Tải một lần, LocalWebServer phục vụ `/canvaskit/*` từ đây.
@immutable
class MiniAppRuntime {
  const MiniAppRuntime({required this.engineRevision, required this.url, required this.sha256, required this.size});

  final String engineRevision;

  /// Đường dẫn tương đối so với server, vd `runtimes/canvaskit-<rev>.zip`.
  final String url;
  final String sha256;
  final int size;

  factory MiniAppRuntime.fromJson(String engineRevision, Map<String, Object?> json) => MiniAppRuntime(
        engineRevision: engineRevision,
        url: json['url'] as String,
        sha256: json['sha256'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {'url': url, 'sha256': sha256, 'size': size};
}

/// Một mini app như mô tả trong `manifest.json` của OTA server.
@immutable
class MiniAppInfo {
  const MiniAppInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.version,
    required this.bundleUrl,
    required this.sha256,
    required this.size,
    required this.runtime,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final String version;

  /// Đường dẫn tương đối so với server, vd `bundles/mini_shop-1.0.0.zip`.
  final String bundleUrl;
  final String sha256;
  final int size;

  /// CanvasKit mà bundle cần (bundle không chứa canvaskit/).
  final MiniAppRuntime runtime;

  // Quyền (bridge, điều hướng chéo) không nằm ở đây mà ở config tổng của
  // Shell (`ShellConfig`), để đổi được mà không cần cập nhật bundle.

  IconData get iconData => switch (icon) {
        'storefront' => Icons.storefront_outlined,
        'wallet' => Icons.account_balance_wallet_outlined,
        'game' => Icons.sports_esports_outlined,
        _ => Icons.apps,
      };

  /// [json] là một entry trong `apps` của manifest, hoặc entry trong registry
  /// (đã gắn sẵn `runtime`). [runtimes] là map `runtimes` của manifest.
  factory MiniAppInfo.fromJson(Map<String, Object?> json, {Map<String, Object?>? runtimes}) {
    final revision = json['engineRevision'] as String? ?? '';
    final runtimeJson = json['runtime'] ?? runtimes?[revision];
    if (revision.isEmpty || runtimeJson is! Map) {
      throw FormatException('Mini app ${json['id']} thiếu runtime (engineRevision=$revision)');
    }
    return MiniAppInfo(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      version: json['version'] as String,
      bundleUrl: json['bundleUrl'] as String,
      sha256: json['sha256'] as String,
      size: (json['size'] as num?)?.toInt() ?? 0,
      runtime: MiniAppRuntime.fromJson(revision, runtimeJson.cast()),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'version': version,
        'bundleUrl': bundleUrl,
        'sha256': sha256,
        'size': size,
        'engineRevision': runtime.engineRevision,
        'runtime': runtime.toJson(),
      };
}

/// Mini app đã tải và giải nén trên máy.
@immutable
class InstalledMiniApp {
  const InstalledMiniApp({
    required this.info,
    required this.directory,
    required this.runtimeDirectory,
    required this.port,
  });

  final MiniAppInfo info;

  /// Thư mục chứa `index.html` (nội dung `build/web`, không có canvaskit/).
  final String directory;

  /// Thư mục runtime chứa `canvaskit/` dùng chung.
  final String runtimeDirectory;

  /// Cổng local cấp lúc cài, duy nhất giữa các mini app và giữ nguyên qua các
  /// lần cập nhật: origin không đổi nên localStorage/IndexedDB được giữ.
  final int port;
}

/// Lỗi cài đặt có thông điệp hiển thị được cho người dùng.
class MiniAppInstallException implements Exception {
  const MiniAppInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Trạng thái hiển thị trên Home: ghép manifest (remote) với bản đã cài (local).
@immutable
class MiniAppListing {
  const MiniAppListing({this.remote, this.installed}) : assert(remote != null || installed != null);

  final MiniAppInfo? remote;
  final InstalledMiniApp? installed;

  MiniAppInfo get info => remote ?? installed!.info;

  bool get needsDownload => installed == null;

  bool get hasUpdate => remote != null && installed != null && remote!.version != installed!.info.version;
}
