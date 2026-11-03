import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:mini_native/mini_native.dart';

import '../config.dart';
import '../native_apps/native_mini_apps.dart';
import '../policy/shell_config.dart';
import '../router/deep_link_handler.dart';
import '../shell_scope.dart';
import 'payment_sheet.dart';

/// Container cho mini app native: không WebView, không bridge JSON. Mini app
/// nhận [MiniNativeHost] và tự dựng AppBar + Navigator riêng; theme lấy thẳng
/// từ `MaterialApp` của Shell.
///
/// Host API kiểm tra cùng bộ quyền với bridge của mini app web
/// ([BridgePermissions]), lấy từ config tổng của Shell.
///
/// Route: `/native/:appId`.
@RoutePage()
class NativeMiniAppPage extends StatefulWidget {
  const NativeMiniAppPage({super.key, @PathParam('appId') required this.appId});

  final String appId;

  @override
  State<NativeMiniAppPage> createState() => _NativeMiniAppPageState();
}

class _NativeMiniAppPageState extends State<NativeMiniAppPage> implements MiniNativeHost {
  late final ShellScope _scope = ShellScope.read(context);
  late final NativeMiniApp? _app = findNativeMiniApp(widget.appId);

  AppPolicy get _policy => _scope.config.value.policyOf(widget.appId);

  @override
  void initState() {
    super.initState();
    _scope.config.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    _scope.config.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (_policy.enabled) return;
    showToast('${_app?.name ?? widget.appId} đã bị tạm khoá');
    close();
  }

  /// Ghi log + báo người dùng khi mini app gọi API mà không có quyền.
  bool _check(String permission) {
    if (_policy.can(permission)) return true;
    debugPrint('[NativeMiniApp] từ chối ${widget.appId}: thiếu quyền "$permission"');
    showToast('${_app?.name ?? widget.appId} không có quyền "$permission"');
    return false;
  }

  @override
  String get name => 'Super App Shell v$kShellVersion';

  @override
  bool get embedded => true;

  @override
  MiniNativeUser? get user => _policy.can(BridgePermissions.userInfo) ? (id: kDemoUser.id, name: kDemoUser.name) : null;

  @override
  void showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Future<bool> requestPayment({required int amount, required String description}) async {
    if (!mounted || !_check(BridgePermissions.payment)) return false;
    return PaymentSheet.show(
      context,
      appName: _app?.name ?? widget.appId,
      params: {'amount': amount, 'description': description},
    );
  }

  @override
  Future<bool> openDeepLink(Uri link) async {
    final app = _app;
    if (app == null || !_check(BridgePermissions.deepLink)) return false;
    final result = await _scope.deepLinks.open(link, caller: MiniAppCaller(app.id));
    return result == DeepLinkResult.opened;
  }

  @override
  void close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    // Bỏ sheet/dialog của Shell phía trên rồi pop trang này. pop() bỏ qua
    // PopScope của mini app, nên không quay lại vòng xử lý Back.
    final router = context.router;
    router.popUntil((r) => r == route);
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app == null) {
      return Scaffold(
        appBar: AppBar(),
        body: DsEmptyState(icon: Icons.error_outline, message: 'Không có mini app native "${widget.appId}"'),
      );
    }
    return app.builder(this);
  }
}
