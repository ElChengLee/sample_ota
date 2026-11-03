import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import '../mini_app/mini_app_repository.dart';
import '../native_apps/native_mini_apps.dart';
import '../navigation/link_policy.dart';
import '../policy/shell_config.dart';
import 'app_router.dart';

export '../navigation/link_policy.dart' show LinkCaller, ShellCaller, SystemCaller, MiniAppCaller;

/// Điều hướng tới route `path` bên trong một mini app đang mở.
typedef MiniAppNavigate = Future<void> Function(String path);

/// Kết quả xử lý một deep link.
enum DeepLinkResult {
  opened,

  /// Link sai định dạng, hoặc không có mini app với id đó.
  invalid,

  /// Mini app web chưa được cài trên máy.
  notInstalled,

  /// Bị [LinkPolicy] chặn, hoặc app đích đang tạm khoá trong config.
  forbidden,
}

/// Điểm vào duy nhất cho mọi deep link [SuperAppLinks], dù đến từ hệ điều hành
/// (intent), từ Home của Shell hay từ mini app (bridge `openDeepLink`, host API).
///
/// - `superapp://open/`: về Home.
/// - `superapp://open/mini-app/<id>?path=…`:
///   - mini app đó đang mở: đưa nó lên trên cùng và gửi `navigate` xuống, để
///     router của mini app tự đổi màn (không load lại WebView, giữ state).
///   - chưa mở: push `MiniAppRoute`, `path` thành fragment URL khởi đầu.
/// - `superapp://open/native/<id>`: mini app native biên dịch sẵn (push
///   `NativeMiniAppRoute`, hoặc đưa lên trên cùng nếu đang mở).
///
/// Trước khi điều hướng, link được kiểm tra bằng [checkLink] theo [LinkCaller]
/// với policy trong config tổng ([ShellConfigStore]): link của mini app phải
/// được cả app gọi lẫn app đích cho phép, và app đích không bị tạm khoá.
class DeepLinkHandler {
  DeepLinkHandler({required this.router, required this.repository, required this.config, required this.messengerKey});

  final AppRouter router;
  final MiniAppRepository repository;
  final ShellConfigStore config;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  final _openApps = <String, ({Route<Object?> route, MiniAppNavigate navigate})>{};

  /// App đã push nhưng page chưa `attach` (guard đang kiểm tra, chưa build).
  /// Chặn 2 link liên tiếp (bấm đúp, mini app gọi 2 lần) push 2 trang cùng app.
  final _launching = <String>{};

  /// `MiniAppPage` đăng ký khi mở, để deep link tới app đang chạy đi qua bridge.
  void attach(String appId, Route<Object?> route, MiniAppNavigate navigate) {
    _launching.remove(appId);
    _openApps[appId] = (route: route, navigate: navigate);
  }

  void detach(String appId, Route<Object?> route) {
    if (_openApps[appId]?.route == route) _openApps.remove(appId);
  }

  /// Nhận cả link đầy đủ (`superapp://open/mini-app/x`) lẫn path (`/mini-app/x`).
  Future<DeepLinkResult> open(Uri link, {LinkCaller caller = const ShellCaller()}) async {
    debugPrint('[DeepLink] open $link (từ $caller)');
    await config.ready;
    final isOurs = !link.hasScheme || (link.isScheme(SuperAppLinks.scheme) && link.host == SuperAppLinks.host);
    final segments = link.pathSegments.where((s) => s.isNotEmpty).toList();
    if (isOurs && segments.isEmpty) {
      router.popUntilRoot();
      return DeepLinkResult.opened;
    }
    if (isOurs && segments.length == 2 && segments.first == 'mini-app') {
      return _openMiniApp(segments[1], link.queryParameters['path'], caller);
    }
    if (isOurs && segments.length == 2 && segments.first == 'native') {
      return _openNativeMiniApp(segments[1], caller);
    }
    _notify('Link không được hỗ trợ: $link');
    return DeepLinkResult.invalid;
  }

  /// Đọc config ngay lúc kiểm tra: config vừa làm mới có hiệu lực ngay.
  bool _allowed(LinkCaller caller, String targetId, String? path) {
    final config = this.config.value;
    final denied = config.policyOf(targetId).enabled
        ? checkLink(caller, targetId: targetId, path: path, policyOf: (id) => config.policyOf(id).links)
        : '$targetId đang tạm khoá';
    if (denied == null) return true;
    _notify('Đã chặn: $denied');
    return false;
  }

  Future<DeepLinkResult> _openMiniApp(String appId, String? path, LinkCaller caller) async {
    final installed = (await repository.installedApps())[appId];
    if (installed == null) {
      _notify('Mini app "$appId" chưa được cài. Hãy tải về từ màn hình chính.');
      return DeepLinkResult.notInstalled;
    }
    if (!_allowed(caller, appId, path)) return DeepLinkResult.forbidden;

    final open = _openApps[appId];
    if (open != null) {
      // Bỏ mọi thứ phía trên (sheet của Shell, mini app khác...) rồi mới điều hướng.
      router.popUntil((r) => r == open.route);
      if (path != null) await open.navigate(path);
      return DeepLinkResult.opened;
    }
    if (!_launching.add(appId)) return DeepLinkResult.opened; // đang mở rồi, bỏ link trùng
    // Không await: Future của push chỉ xong khi mini app đóng lại (hoặc guard từ chối).
    router.push(MiniAppRoute(appId: appId, initialPath: path)).whenComplete(() => _launching.remove(appId)).ignore();
    return DeepLinkResult.opened;
  }

  DeepLinkResult _openNativeMiniApp(String appId, LinkCaller caller) {
    final app = findNativeMiniApp(appId);
    if (app == null) {
      _notify('Không có mini app native "$appId".');
      return DeepLinkResult.invalid;
    }
    if (!_allowed(caller, appId, null)) return DeepLinkResult.forbidden;

    bool isTarget(RouteData data) =>
        data.name == NativeMiniAppRoute.name && data.params.optString('appId') == appId;
    if (router.stack.any((page) => isTarget(page.routeData))) {
      // Đang mở: bỏ mọi thứ phía trên (sheet, mini app khác) để đưa nó lên trên cùng.
      router.popUntil((route) => route.settings is AutoRoutePage && isTarget((route.settings as AutoRoutePage).routeData));
      return DeepLinkResult.opened;
    }
    router.push(NativeMiniAppRoute(appId: appId)).ignore();
    return DeepLinkResult.opened;
  }

  void _notify(String message) {
    debugPrint('[DeepLink] $message');
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }
}
