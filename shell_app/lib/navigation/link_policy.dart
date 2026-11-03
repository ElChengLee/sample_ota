import 'package:flutter/foundation.dart';

/// Quyền điều hướng chéo của một mini app, khai báo trong config tổng của
/// Shell (`server/shell_config.json`, mục `apps.<id>.links`):
///
/// ```json
/// "links": {
///   "canOpen":    ["mini_game", "mini_native"],   // phía GỌI: được mở app nào
///   "openableBy": ["*"],                          // phía BỊ GỌI: app nào được mở mình
///   "exported":   ["/", "/product/*"]             // màn nào cho bên ngoài mở thẳng vào
/// }
/// ```
///
/// Một link từ app A sang app B chỉ được mở khi **cả hai phía đồng ý**: B có
/// trong `A.canOpen` và A có trong `B.openableBy`, đồng thời `path` khớp
/// `B.exported`. Config được server ký nên mini app không tự nới được. Thiếu
/// khai báo thì mặc định là chặn hết.
@immutable
class LinkPolicy {
  const LinkPolicy({this.canOpen = const {}, this.openableBy = const {}, this.exported = const {'/'}});

  /// Mặc định khi không khai báo: không mở app khác, chỉ Shell và hệ điều hành
  /// mở được màn gốc.
  static const none = LinkPolicy();

  static const wildcard = '*';

  final Set<String> canOpen;
  final Set<String> openableBy;

  /// Mẫu path: `/` (màn gốc), `/product/*` (`*` khớp đúng một đoạn),
  /// `/a/**` (`**` ở cuối khớp mọi đoạn còn lại).
  final Set<String> exported;

  factory LinkPolicy.fromJson(Object? json) {
    if (json is! Map) return none;
    Set<String> read(String key, Set<String> fallback) =>
        json[key] is List ? {...(json[key] as List).cast<String>()} : fallback;
    return LinkPolicy(
      canOpen: read('canOpen', const {}),
      openableBy: read('openableBy', const {}),
      exported: read('exported', const {'/'}),
    );
  }

  Map<String, Object?> toJson() => {
        'canOpen': canOpen.toList(),
        'openableBy': openableBy.toList(),
        'exported': exported.toList(),
      };

  bool allowsOpening(String appId) => canOpen.contains(wildcard) || canOpen.contains(appId);

  bool openableFrom(String appId) => openableBy.contains(wildcard) || openableBy.contains(appId);

  bool exportsPath(String? path) => exported.any((pattern) => matchPath(pattern, path ?? '/'));

  /// `*` khớp đúng một đoạn, `**` ở cuối khớp phần còn lại (kể cả rỗng).
  static bool matchPath(String pattern, String path) {
    List<String> split(String s) => Uri.parse(s).pathSegments.where((e) => e.isNotEmpty).toList();
    final p = split(pattern);
    final s = split(path);
    for (var i = 0; i < p.length; i++) {
      if (p[i] == '**' && i == p.length - 1) return true;
      if (i >= s.length) return false;
      if (p[i] != '*' && p[i] != s[i]) return false;
    }
    return p.length == s.length;
  }

  @override
  bool operator ==(Object other) =>
      other is LinkPolicy &&
      setEquals(other.canOpen, canOpen) &&
      setEquals(other.openableBy, openableBy) &&
      setEquals(other.exported, exported);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(canOpen), Object.hashAllUnordered(openableBy),
      Object.hashAllUnordered(exported));
}

/// Ai gửi deep link. Quyết định link phải qua những kiểm tra nào.
sealed class LinkCaller {
  const LinkCaller();
}

/// UI của chính Shell (nút trên Home…): tin cậy, không kiểm tra.
final class ShellCaller extends LinkCaller {
  const ShellCaller();

  @override
  String toString() => 'Shell';
}

/// Intent từ hệ điều hành: app bất kỳ trên máy đều gửi được, nên chỉ được mở
/// các màn mà mini app đích đã `exported`.
final class SystemCaller extends LinkCaller {
  const SystemCaller();

  @override
  String toString() => 'hệ điều hành';
}

/// Một mini app (web qua bridge, hoặc native qua host API). Policy của nó
/// được tra từ config lúc kiểm tra, không đi kèm link.
final class MiniAppCaller extends LinkCaller {
  const MiniAppCaller(this.appId);

  final String appId;

  @override
  String toString() => appId;
}

/// Lý do một link bị chặn, `null` nếu được phép.
///
/// [targetId] là app đích, [path] là màn đích bên trong (`null` = màn gốc),
/// [policyOf] tra policy của một app theo id.
String? checkLink(
  LinkCaller caller, {
  required String targetId,
  String? path,
  required LinkPolicy Function(String appId) policyOf,
}) {
  final targetPolicy = policyOf(targetId);
  switch (caller) {
    case ShellCaller():
      return null;
    case SystemCaller():
      return targetPolicy.exportsPath(path) ? null : '$targetId không cho mở thẳng vào "$path" từ bên ngoài';
    case MiniAppCaller(:final appId):
      if (appId == targetId) return null; // điều hướng trong chính nó
      if (!policyOf(appId).allowsOpening(targetId)) return '$appId không khai báo quyền mở $targetId (canOpen)';
      if (!targetPolicy.openableFrom(appId)) return '$targetId không cho $appId mở (openableBy)';
      if (!targetPolicy.exportsPath(path)) return '$targetId không cho mở thẳng vào "$path" (exported)';
      return null;
  }
}
