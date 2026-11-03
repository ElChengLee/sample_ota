import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../mini_app/mini_app_repository.dart';
import '../navigation/link_policy.dart';

/// Quyền của một mini app (web hoặc native) theo config tổng của Shell.
@immutable
class AppPolicy {
  const AppPolicy({this.enabled = true, this.permissions = const {}, this.links = LinkPolicy.none});

  /// App không có trong config: mở được từ Home, nhưng không có quyền bridge
  /// nào và không mở chéo được.
  static const unlisted = AppPolicy();

  /// `false`: tạm khoá (kill switch). Không mở được, đang mở thì bị đóng.
  final bool enabled;

  /// Quyền bridge / host API (xem `BridgePermissions`).
  final Set<String> permissions;

  /// Quyền điều hướng chéo.
  final LinkPolicy links;

  bool can(String permission) => permissions.contains(permission);

  factory AppPolicy.fromJson(Object? json) {
    if (json is! Map) return unlisted;
    return AppPolicy(
      enabled: json['enabled'] as bool? ?? true,
      permissions: {...(json['permissions'] as List? ?? const []).cast<String>()},
      links: LinkPolicy.fromJson(json['links']),
    );
  }

  Map<String, Object?> toJson() => {'enabled': enabled, 'permissions': permissions.toList(), 'links': links.toJson()};

  @override
  bool operator ==(Object other) =>
      other is AppPolicy && other.enabled == enabled && setEquals(other.permissions, permissions) && other.links == links;

  @override
  int get hashCode => Object.hash(enabled, Object.hashAllUnordered(permissions), links);
}

/// Config tổng do server phát hành (`server/shell_config.json`, ký Ed25519),
/// nguồn duy nhất cho quyền của mọi mini app. Sửa trên server là các máy nhận
/// ở lần làm mới tiếp theo, không cần phát hành lại Shell hay mini app.
@immutable
class ShellConfig {
  const ShellConfig({required this.version, this.apps = const {}});

  /// Chưa từng tải được config: mọi app đều [AppPolicy.unlisted] (an toàn).
  static const empty = ShellConfig(version: 0);

  /// Tăng dần mỗi lần phát hành. Shell không nhận config có version nhỏ hơn
  /// bản đang giữ, để không ai phát lại được một config cũ (đã ký hợp lệ)
  /// nhằm lấy lại quyền đã bị thu hồi.
  final int version;
  final Map<String, AppPolicy> apps;

  AppPolicy policyOf(String appId) => apps[appId] ?? AppPolicy.unlisted;

  factory ShellConfig.fromJson(Map<String, Object?> json) => ShellConfig(
        version: (json['version'] as num).toInt(),
        apps: {
          for (final MapEntry(:key, :value) in (json['apps'] as Map? ?? const {}).entries)
            key as String: AppPolicy.fromJson(value),
        },
      );

  Map<String, Object?> toJson() => {
        'version': version,
        'apps': {for (final MapEntry(:key, :value) in apps.entries) key: value.toJson()},
      };
}

/// Giữ [ShellConfig] hiện hành và làm mới từ server.
///
/// - Khởi động: [load] bản đã lưu trên máy (dùng được khi offline), rồi [refresh].
/// - [refresh] được gọi lúc mở app, khi app quay lại foreground và khi kéo làm
///   mới ở Home. Chữ ký sai hoặc version cũ hơn thì giữ nguyên bản đang có.
/// - Nơi kiểm tra quyền đọc [value] ngay lúc kiểm tra, nên config mới có hiệu
///   lực cả với mini app đang mở.
class ShellConfigStore extends ValueNotifier<ShellConfig> {
  ShellConfigStore({required this.repository}) : super(ShellConfig.empty);

  static const fileName = 'shell_config.json';

  final MiniAppRepository repository;
  Future<bool>? _refreshing;
  Future<void>? _ready;

  /// Xong khi đã có config để kiểm tra quyền: bản lưu trên máy, hoặc (lần đầu
  /// chạy, chưa có bản lưu) sau lần tải đầu tiên. Deep link lúc cold start chờ
  /// cái này, để không bị chặn oan bởi [ShellConfig.empty].
  Future<void> get ready => _ready ??= () async {
        await load();
        if (value.version == 0) {
          await refresh();
        } else {
          refresh().ignore();
        }
      }();

  Future<File> get _cacheFile async => File(p.join((await repository.rootDirectory).path, fileName));

  Future<void> load() async {
    try {
      final file = await _cacheFile;
      if (!file.existsSync()) return;
      final config = ShellConfig.fromJson((jsonDecode(await file.readAsString()) as Map).cast());
      if (config.version > value.version) value = config;
    } on Object catch (e) {
      debugPrint('[Config] bản lưu trên máy hỏng, bỏ qua: $e');
    }
  }

  /// `true` nếu đang giữ config mới nhất của server. Nhiều lần gọi cùng lúc
  /// dùng chung một request.
  Future<bool> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    try {
      final config = ShellConfig.fromJson(await repository.fetchSignedJson(fileName));
      if (config.version < value.version) {
        debugPrint('[Config] bỏ qua config v${config.version}, cũ hơn bản đang giữ v${value.version}');
        return false;
      }
      if (config.version == value.version) return true;
      final file = await _cacheFile;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(config.toJson()), flush: true);
      await tmp.rename(file.path);
      debugPrint('[Config] áp dụng config v${config.version} (trước đó v${value.version})');
      value = config;
      return true;
    } on Object catch (e) {
      debugPrint('[Config] không làm mới được, giữ v${value.version}: $e');
      return false;
    }
  }
}
