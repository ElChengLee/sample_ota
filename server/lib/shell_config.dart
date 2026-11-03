/// Kiểm tra file config tổng `shell_config.json` (quyền + điều hướng chéo của
/// mọi mini app) trước khi ký. Trả bản chuẩn hoá, ném [FormatException] với
/// thông điệp chỉ rõ chỗ sai.
library;

/// Quyền bridge Shell hiểu được (xem `BridgePermissions` trong mini_app_bridge).
const knownPermissions = {'userInfo', 'payment', 'deepLink'};

final _appIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

Map<String, Object?> validateShellConfig(Object? raw) {
  if (raw is! Map) throw const FormatException('config phải là object');
  _noUnknownKeys('config', raw, const {'version', 'apps'});
  final apps = raw['apps'];
  if (apps is! Map) throw const FormatException('config.apps phải là object {"<appId>": {...}}');
  return {
    for (final MapEntry(:key, :value) in apps.entries) key as String: _validateApp(key, value),
  };
}

Map<String, Object?> _validateApp(String id, Object? raw) {
  if (!_appIdPattern.hasMatch(id)) throw FormatException('id không hợp lệ: "$id"');
  if (raw is! Map) throw FormatException('$id phải là object');
  _noUnknownKeys(id, raw, const {'enabled', 'permissions', 'links'});

  final enabled = raw['enabled'] ?? true;
  if (enabled is! bool) throw FormatException('$id.enabled phải là true/false');

  final permissions = _stringList(raw, 'permissions', id, const []);
  final unknown = permissions.where((perm) => !knownPermissions.contains(perm));
  if (unknown.isNotEmpty) {
    throw FormatException('$id.permissions có quyền lạ: ${unknown.join(', ')} (hợp lệ: ${knownPermissions.join(', ')})');
  }

  final links = raw['links'] ?? const {};
  if (links is! Map) throw FormatException('$id.links phải là object');
  _noUnknownKeys('$id.links', links, const {'canOpen', 'openableBy', 'exported'});
  final canOpen = _stringList(links, 'canOpen', '$id.links', const []);
  final openableBy = _stringList(links, 'openableBy', '$id.links', const []);
  final exported = _stringList(links, 'exported', '$id.links', const ['/']);
  for (final appId in [...canOpen, ...openableBy]) {
    if (appId != '*' && !_appIdPattern.hasMatch(appId)) throw FormatException('$id.links chứa id không hợp lệ: "$appId"');
  }
  for (final pattern in exported) {
    final segments = pattern.split('/').skip(1).toList();
    final doubleStar = segments.indexOf('**');
    if (!pattern.startsWith('/') || (doubleStar >= 0 && doubleStar != segments.length - 1)) {
      throw FormatException('$id.links.exported "$pattern" phải bắt đầu bằng "/", "**" chỉ được ở cuối');
    }
  }
  if (canOpen.isNotEmpty && !permissions.contains('deepLink')) {
    throw FormatException('$id.links.canOpen cần quyền "deepLink" trong $id.permissions');
  }

  return {
    'enabled': enabled,
    'permissions': permissions,
    'links': {'canOpen': canOpen, 'openableBy': openableBy, 'exported': exported},
  };
}

void _noUnknownKeys(String where, Map<Object?, Object?> map, Set<String> allowed) {
  final unknown = map.keys.where((k) => !allowed.contains(k));
  if (unknown.isNotEmpty) throw FormatException('$where có khoá lạ: ${unknown.join(', ')}');
}

List<String> _stringList(Map<Object?, Object?> map, String key, String where, List<String> fallback) {
  final value = map[key];
  if (value == null) return fallback;
  if (value is! List || value.any((e) => e is! String)) throw FormatException('$where.$key phải là mảng chuỗi');
  return value.cast<String>();
}
