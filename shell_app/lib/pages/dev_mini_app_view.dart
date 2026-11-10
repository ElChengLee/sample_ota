import 'package:app_theme/app_theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../policy/shell_config.dart';
import '../router/deep_link_handler.dart';
import '../shell_scope.dart';
import 'dev_origin.dart';
import 'payment_sheet.dart';

/// Màn riêng: load một URL http(s) và gắn `ShellBridge` theo id mini app.
///
/// Không có local server, không đòi mini app đã cài, không nhận deep link hệ
/// điều hành (deep link đó vẫn vào [MiniAppPage]).
class DevMiniAppView extends StatefulWidget {
  const DevMiniAppView({super.key, required this.url, required this.appId});

  final Uri url;
  final String appId;

  @override
  State<DevMiniAppView> createState() => DevMiniAppViewState();
}

class DevMiniAppViewState extends State<DevMiniAppView> {
  late final ShellScope _scope = ShellScope.read(context);
  late final WebViewController _webView;
  late final ShellBridgeHost _bridge;

  /// Route của màn này, để `close` và back đóng đúng trang kể cả khi đang có sheet.
  ModalRoute<Object?>? _route;

  /// Origin được phép đi tiếp. `null` khi chưa load.
  Uri? _loaded;

  /// Id đang mở.
  late String _appId = widget.appId;

  /// Đã handshake (`init`) thì back hỏi mini app và theme được đẩy xuống.
  var _connected = false;
  var _handlingBack = false;
  ThemeSpec? _lastSentTheme;
  String? _error;

  ThemeController get _themeController => _scope.themeController;

  /// Quyền đọc lúc gọi: config vừa đổi có hiệu lực ngay.
  AppPolicy get _policy => devPolicyFor(_scope.config.value, _appId);

  @override
  void initState() {
    super.initState();
    _bridge = ShellBridgeHost(
      runJavaScript: (script) => _webView.runJavaScript(script),
      hasPermission: (permission) => _policy.can(permission),
      handlers: {
        BridgeMethods.init: (_) async {
          final theme = _resolvedTheme();
          _lastSentTheme = theme;
          if (mounted) setState(() => _connected = true);
          return devInitResult(
            theme: theme,
            includeUser: _policy.can(BridgePermissions.userInfo),
          );
        },
        BridgeMethods.getUserInfo: (_) async => kDemoUser.toJson(),
        BridgeMethods.showToast: (params) async {
          _showSnackBar('${params['message']}');
          return null;
        },
        BridgeMethods.requestPayment: (params) async {
          final ok = await PaymentSheet.show(
            context,
            appName: _appId,
            params: params,
          );
          return {
            'status': ok ? 'success' : 'cancelled',
            if (ok)
              'transactionId': 'TX${DateTime.now().millisecondsSinceEpoch}',
          };
        },
        BridgeMethods.close: (_) async {
          _closeDevPage();
          return null;
        },
        BridgeMethods.openDeepLink: (params) async {
          final url = Uri.tryParse('${params['url']}');
          if (url == null) return {'opened': false, 'error': 'invalid'};
          final result = await _scope.deepLinks.open(
            url,
            caller: MiniAppCaller(_appId),
          );
          return {
            'opened': result == DeepLinkResult.opened,
            if (result != DeepLinkResult.opened) 'error': result.name,
          };
        },
      },
    );

    _webView = _scope.webViews.take()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        kShellChannelName,
        onMessageReceived: (m) => _bridge.handleIncoming(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _connected = false);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _error = null);
          },
          onNavigationRequest: _onNavigationRequest,
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() => _error = error.description);
            }
          },
        ),
      );

    _themeController.addListener(_syncTheme);
    _scope.config.addListener(_onConfigChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openUrl(widget.url, widget.appId);
    });
  }

  /// App đang mở bị tắt sau khi URL đã load: không trả lời bridge nữa.
  void _onConfigChanged() {
    if (_loaded == null) return;
    final denied = devLockMessage(_appId, _policy);
    if (denied == null) return;
    _showSnackBar(denied);
    _closeDevPage();
  }

  /// Load [url] cho [appId] nếu app đó không bị tạm khoá. Query theme được gắn, fragment giữ nguyên.
  Future<void> openUrl(Uri url, String appId) async {
    _appId = appId;
    final denied = devLockMessage(_appId, _policy);
    if (denied != null) {
      _showSnackBar(denied);
      return;
    }
    final themed = applyDevTheme(url, _resolvedTheme());
    _loaded = themed;
    _lastSentTheme = null;
    if (mounted) {
      setState(() {
        _error = null;
        _connected = false;
      });
    }
    await _webView.loadRequest(themed);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final loaded = _loaded;
    if (loaded == null) return NavigationDecision.prevent;
    final blocked = devNavigationBlockMessage(loaded, request.url);
    if (blocked == null) return NavigationDecision.navigate;
    if (!request.isMainFrame) return NavigationDecision.prevent;
    debugPrint('[Dev] blocked navigation: ${request.url}');
    _showSnackBar(blocked);
    return NavigationDecision.prevent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
    // Đăng ký phụ thuộc vào platform brightness để bắt thay đổi khi mode = system.
    MediaQuery.platformBrightnessOf(context);
    _syncTheme();
  }

  ThemeSpec _resolvedTheme() => _themeController.value.resolve(
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  void _syncTheme() {
    if (!_connected) return;
    final theme = _resolvedTheme();
    if (theme == _lastSentTheme) return;
    _lastSentTheme = theme;
    _bridge.emit(BridgeEvents.themeChanged, theme.toJson());
  }

  /// Back hỏi mini app trước. Không trả lời hoặc `handled: false` thì đóng màn này.
  Future<void> handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      var handled = false;
      if (_connected) {
        try {
          final result = await _bridge.request(MiniAppMethods.backPressed);
          handled = result is Map && result['handled'] == true;
        } on Object catch (e) {
          debugPrint('[Dev] backPressed không được trả lời, đóng /dev: $e');
        }
      }
      if (!handled) _closeDevPage();
    } finally {
      _handlingBack = false;
    }
  }

  void _closeDevPage() {
    final route = _route;
    if (!mounted || route == null || !route.isActive) return;
    final router = context.router;
    router.popUntil((r) => r == route);
    router.pop();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _themeController.removeListener(_syncTheme);
    _scope.config.removeListener(_onConfigChanged);
    _bridge.dispose();
    final pool = _scope.webViews;
    Future<void>.delayed(const Duration(milliseconds: 500), pool.warmUp);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(widget.appId),
          actions: [
            IconButton(
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
              onPressed: _closeDevPage,
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(top: false, child: WebViewWidget(controller: _webView)),
            if (_error != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Material(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpacing.sm),
                    child: Text(_error!, style: theme.textTheme.bodyMedium),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
