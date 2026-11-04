import 'package:app_theme/app_theme.dart';

import '../config.dart';
import '../policy/shell_config.dart';

/// Mini app mà WebView debug mượn quyền và deep link. Không đòi bản đã cài.
const kDevMiniAppId = 'mini_shop';

/// Hiện dưới ô URL khi chuỗi rỗng hoặc không phải http(s) có host.
const kDevUrlError = 'Nhập URL http hoặc https có host.';

/// `null` khi [raw] rỗng hoặc không phải URL http(s) có host.
/// Nút **Mở** chỉ bật khi hàm này trả về một [Uri].
Uri? parseDevUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !_isHttpWithHost(uri)) return null;
  return uri;
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

/// `mini_shop` tắt trong config: SnackBar, không `loadRequest`. `null` nếu được load.
String? devShopLockMessage(AppPolicy policy) =>
    policy.enabled ? null : 'Mini app "$kDevMiniAppId" đang tạm khoá.';

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
