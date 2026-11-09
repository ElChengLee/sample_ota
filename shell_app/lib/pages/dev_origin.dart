import 'dart:io';

import 'package:app_theme/app_theme.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../policy/shell_config.dart';

/// Id điền sẵn. Dev không gắn cứng id này lúc load.
const kDevDefaultAppId = 'mini_shop';

/// URL điền sẵn. User tự thêm cổng, ví dụ `7357`.
const kDevDefaultUrl = 'http://localhost:';

/// File trong application support, chỉ chứa cổng lần nhập cuối.
const devLastPortFileName = 'dev_last_port.txt';

/// Hiện dưới ô URL khi chuỗi rỗng hoặc không phải http(s) có host.
const kDevUrlError = 'Nhập URL http hoặc https có host.';

/// Hiện dưới ô id khi không phải `chữ_thường` như `mini_shop`.
const kDevAppIdError = 'Nhập id: chữ thường, số và _.';

final _devAppId = RegExp(r'^[a-z][a-z0-9_]*$');

/// `null` khi [raw] rỗng hoặc không phải URL http(s) có host.
/// Nút **Mở** chỉ bật khi hàm này trả về một [Uri].
Uri? parseDevUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text.endsWith(':')) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !_isHttpWithHost(uri)) return null;
  return uri;
}

/// Cổng ghi tường minh trong URL. `null` khi chưa có cổng, ví dụ `http://localhost:`.
String? devExplicitPort(String raw) {
  final uri = parseDevUrl(raw);
  if (uri == null || !uri.hasPort) return null;
  return '${uri.port}';
}

/// Ghép cổng đã lưu vào [kDevDefaultUrl].
String devUrlForPort(String port) => '$kDevDefaultUrl$port';

/// Đọc cổng đã lưu. `null` khi chưa có file hoặc nội dung không phải cổng 1–65535.
String? readDevLastPort(Directory dir) {
  final file = File(p.join(dir.path, devLastPortFileName));
  if (!file.existsSync()) return null;
  final value = int.tryParse(file.readAsStringSync().trim());
  if (value == null || value < 1 || value > 65535) return null;
  return '$value';
}

/// Ghi đè cổng lần nhập cuối. Bỏ qua chuỗi không phải cổng.
void writeDevLastPort(Directory dir, String port) {
  final value = int.tryParse(port);
  if (value == null || value < 1 || value > 65535) return;
  dir.createSync(recursive: true);
  File(p.join(dir.path, devLastPortFileName)).writeAsStringSync('$value');
}

/// Gắn query theme (`mode`, `brand`, `seed`) như `MiniAppPage._load`, giữ path,
/// query sẵn có và fragment.
Uri applyDevTheme(Uri url, ThemeSpec theme) {
  final themeQuery = theme.toJson().map(
    (key, value) => MapEntry(key, '$value'),
  );
  return url.replace(queryParameters: {...url.queryParameters, ...themeQuery});
}

/// Chỉ http(s) cùng origin với URL đã load. Scheme lạ (`intent:`, `tel:`) là false.
bool allowsDevNavigation(Uri loaded, String requestUrl) {
  final target = Uri.tryParse(requestUrl);
  if (target == null || !_isHttpWithHost(loaded) || !_isHttpWithHost(target)) {
    return false;
  }
  return target.origin == loaded.origin;
}

/// Thông điệp SnackBar khi chặn điều hướng. `null` nếu được phép đi tiếp.
String? devNavigationBlockMessage(Uri loaded, String requestUrl) {
  if (allowsDevNavigation(loaded, requestUrl)) return null;
  final host = Uri.tryParse(requestUrl)?.host;
  final where = (host != null && host.isNotEmpty) ? host : requestUrl;
  return 'Đã chặn mini app mở trang ngoài: $where';
}

/// Id mini app đang debug. `null` khi rỗng hoặc có ký tự ngoài `a-z`, `0-9`, `_`.
String? parseDevAppId(String raw) {
  final text = raw.trim();
  if (!_devAppId.hasMatch(text)) return null;
  return text;
}

/// Policy lúc load WebView debug.
///
/// Id có trong config thì dùng đúng quyền đó (kể cả tạm khoá). Id chưa khai —
/// mini app mới đang viết — được đủ quyền bridge để gọi user, thanh toán và
/// deep link, giống `mini_shop`, không cần phát hành config trước.
AppPolicy devPolicyFor(ShellConfig config, String appId) =>
    config.apps[appId] ?? const AppPolicy(permissions: BridgePermissions.all);

/// App đang tắt trong config: SnackBar, không `loadRequest`. `null` nếu được load.
String? devLockMessage(String appId, AppPolicy policy) =>
    policy.enabled ? null : 'Mini app "$appId" đang tạm khoá.';

/// Payload `init` của trang debug. `user` chỉ có khi policy cho `userInfo`.
Map<String, Object?> devInitResult({
  required ThemeSpec theme,
  required bool includeUser,
}) => {
  'theme': theme.toJson(),
  if (includeUser) 'user': kDemoUser.toJson(),
  'appVersion': 'dev',
  'shellVersion': kShellVersion,
};

bool _isHttpWithHost(Uri uri) =>
    (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
