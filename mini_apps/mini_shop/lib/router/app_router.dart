import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

import 'app_router.gr.dart';

export 'app_router.gr.dart';

/// Route của mini app (Flutter web, hash strategy):
/// ```
/// #/                      ShopRoute
/// #/product/:productId    ProductDetailRoute
/// ```
/// Shell vào thẳng một màn bằng hai cách:
/// - lúc mở mini app: gắn fragment, vd `index.html#/product/p2` -> [buildDeepLink];
/// - mini app đang mở: gửi `navigate` qua bridge -> [navigateFromShell].
///
/// [routes] là nơi duy nhất khai báo path: deep link dùng chính matcher của
/// auto_route, thêm route mới là deep link vào được ngay.
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: ShopRoute.page, path: '/', initial: true),
        AutoRoute(page: ProductDetailRoute.page, path: '/product/:productId'),
      ];

  /// Stack cho một path. Luôn có Shop ở dưới để Back quay về danh sách thay
  /// vì đóng cả mini app. `null` nếu không có route nào khớp.
  List<PageRouteInfo>? stackFor(Uri uri) {
    final matches = matcher.match(uri.path.isEmpty ? '/' : uri.path);
    if (matches == null || matches.isEmpty) return null;
    final stack = [for (final match in matches) match.toPageRouteInfo()];
    return stack.first.routeName == ShopRoute.name ? stack : [const ShopRoute(), ...stack];
  }

  DeepLink buildDeepLink(PlatformDeepLink link) {
    final stack = stackFor(link.uri);
    return stack == null ? DeepLink.defaultPath : DeepLink(stack);
  }

  /// Ném lỗi khi không có route: bridge trả lỗi về, Shell báo cho người dùng.
  Future<void> navigateFromShell(String path) async {
    final stack = stackFor(Uri.parse(path));
    if (stack == null) throw ArgumentError('không có route $path');
    // Đóng dialog/sheet đang mở trước, rồi dựng lại stack.
    popUntil((route) => route.settings is Page);
    await replaceAll(stack);
  }
}
