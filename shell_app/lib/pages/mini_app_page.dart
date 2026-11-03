import 'package:app_theme/app_theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../mini_app/local_web_server.dart';
import '../mini_app/mini_app_models.dart';
import '../policy/shell_config.dart';
import '../router/deep_link_handler.dart';
import '../shell_scope.dart';
import 'payment_sheet.dart';
import 'theme_settings.dart';

/// Container chạy mini app: AppBar native + WebView trỏ vào local server.
///
/// Route: `/mini-app/:appId?path=/product/p2`. [initialPath] là route bên trong
/// mini app, được gắn vào fragment URL (`index.html#/product/p2`) để router của
/// mini app (auto_route, hash strategy) mở thẳng màn đó.
@RoutePage()
class MiniAppPage extends StatefulWidget {
  const MiniAppPage({super.key, @PathParam('appId') required this.appId, @QueryParam('path') this.initialPath});

  final String appId;
  final String? initialPath;

  @override
  State<MiniAppPage> createState() => _MiniAppPageState();
}

class _MiniAppPageState extends State<MiniAppPage> {
  late final ShellScope _scope = ShellScope.read(context);
  late final WebViewController _webView;
  late final ShellBridgeHost _bridge;
  LocalWebServer? _server;
  InstalledMiniApp? _app;
  late String? _path = widget.initialPath;

  /// Route của chính trang này, để `close` đóng đúng mini app kể cả khi đang
  /// có sheet/dialog của Shell (vd PaymentSheet) nằm phía trên.
  ModalRoute<Object?>? _route;

  /// Mini App đã handshake xong (gọi `init`) -> ẩn loader và bắt đầu đồng bộ theme.
  var _connected = false;
  var _handlingBack = false;

  /// Đo thời gian mở mini app (log `[MiniApp] ... sẵn sàng sau`).
  final _openWatch = Stopwatch()..start();
  final _openMarks = <String>[];
  void _mark(String step) => _openMarks.add('$step ${_openWatch.elapsedMilliseconds}');
  ThemeSpec? _lastSentTheme;
  String? _error;

  ThemeController get _themeController => _scope.themeController;

  /// Đọc config ngay lúc cần: quyền vừa đổi trên server có hiệu lực ngay cả
  /// khi mini app đang mở.
  AppPolicy get _policy => _scope.config.value.policyOf(widget.appId);

  @override
  void initState() {
    super.initState();
    _bridge = ShellBridgeHost(
      runJavaScript: (script) => _webView.runJavaScript(script),
      // Quyền lấy từ config tổng đã ký của Shell, không tin mini app tự khai.
      hasPermission: (permission) => _policy.can(permission),
      handlers: {
        BridgeMethods.init: (_) async {
          final theme = _resolvedTheme();
          _lastSentTheme = theme;
          setState(() => _connected = true);
          if (_openWatch.isRunning) {
            _openWatch.stop();
            debugPrint('[MiniApp] ${widget.appId} sẵn sàng sau ${_openWatch.elapsedMilliseconds}ms (${_openMarks.join(', ')})');
          }
          return {
            'theme': theme.toJson(),
            if (_policy.can(BridgePermissions.userInfo)) 'user': kDemoUser.toJson(),
            'appVersion': _app!.info.version,
            'shellVersion': kShellVersion,
          };
        },
        BridgeMethods.getUserInfo: (_) async => kDemoUser.toJson(),
        BridgeMethods.showToast: (params) async {
          _showSnackBar('${params['message']}');
          return null;
        },
        BridgeMethods.requestPayment: (params) async {
          final ok = await PaymentSheet.show(context, appName: _app!.info.name, params: params);
          return {
            'status': ok ? 'success' : 'cancelled',
            if (ok) 'transactionId': 'TX${DateTime.now().millisecondsSinceEpoch}',
          };
        },
        BridgeMethods.close: (_) async {
          _closeMiniApp();
          return null;
        },
        BridgeMethods.openDeepLink: (params) async {
          final url = Uri.tryParse('${params['url']}');
          final app = _app;
          if (url == null || app == null) return {'opened': false, 'error': 'invalid'};
          final result = await _scope.deepLinks.open(url, caller: MiniAppCaller(app.info.id));
          return {'opened': result == DeepLinkResult.opened, if (result != DeepLinkResult.opened) 'error': result.name};
        },
      },
    );

    _webView = _scope.webViews.take()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(kShellChannelName, onMessageReceived: (m) => _bridge.handleIncoming(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _mark('pageStarted'),
        onPageFinished: (_) => _mark('pageFinished'),
        onNavigationRequest: _onNavigationRequest,
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) setState(() => _error = error.description);
        },
      ));

    _themeController.addListener(_syncTheme);
    _scope.config.addListener(_onConfigChanged);
    _launch();
  }

  /// Bị tạm khoá trong config mới thì đóng ngay.
  void _onConfigChanged() {
    if (_policy.enabled) return;
    _showSnackBar('${_app?.info.name ?? widget.appId} đã bị tạm khoá');
    _closeMiniApp();
  }

  Future<void> _launch() async {
    try {
      final app = (await _scope.repository.installedApps())[widget.appId];
      if (app == null) throw MiniAppInstallException('Mini app "${widget.appId}" chưa được cài');
      if (!mounted) return;
      setState(() => _app = app);
      _mark('registry');

      final server = await LocalWebServer.start(
        app.directory,
        runtimeDirectory: app.runtimeDirectory,
        port: app.port,
      );
      if (!mounted) return await server.close();
      _server = server;
      _mark('server');
      await _load(_path);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Query: theme để frame đầu của mini app đã đúng màu.
  /// Fragment: route khởi đầu của mini app (deep link vào màn con).
  Future<void> _load(String? path) {
    final url = _server!.origin.replace(
      path: '/index.html',
      queryParameters: _resolvedTheme().toJson().cast(),
      fragment: path,
    );
    return _webView.loadRequest(url);
  }

  /// Deep link tới mini app đang mở (từ [DeepLinkHandler]). Ưu tiên gửi
  /// `navigate` qua bridge để giữ nguyên state; chỉ load lại WebView khi mini
  /// app chưa sẵn sàng hoặc không trả lời.
  Future<void> _navigateTo(String path) async {
    if (_server == null) {
      _path = path; // Đang khởi động: _launch sẽ load luôn path này.
      return;
    }
    if (_connected) {
      try {
        await _bridge.request(MiniAppMethods.navigate, params: {'path': path});
        return;
      } on BridgeException catch (e) {
        // Mini app trả lỗi (vd route không tồn tại): giữ nguyên màn hiện tại.
        debugPrint('[MiniApp] navigate $path bị từ chối: ${e.message}');
        _showSnackBar('${_app?.info.name ?? widget.appId} không có màn "$path"');
        return;
      } on Object catch (e) {
        debugPrint('[MiniApp] navigate không được trả lời, load lại WebView: $e');
      }
    }
    if (!mounted) return;
    setState(() => _connected = false);
    await _load(path);
  }

  /// Chỉ cho WebView ở trong origin local của mini app. Trang ngoài vẫn sẽ có
  /// `window.ShellBridge`, nên không thể để nó load trong WebView này.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final origin = _server?.origin;
    final target = Uri.tryParse(request.url);
    final isHttp = target != null && (target.isScheme('http') || target.isScheme('https'));
    // Uri.origin chỉ hợp lệ với http/https; các scheme khác (intent:, tel:, about:...) đều chặn.
    if (origin != null && isHttp && target.origin == origin.origin) {
      return NavigationDecision.navigate;
    }
    debugPrint('[MiniApp] blocked navigation: ${request.url}');
    _showSnackBar('Đã chặn mini app mở trang ngoài: ${target?.host ?? request.url}');
    return NavigationDecision.prevent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_route == null) {
      _route = ModalRoute.of(context);
      if (_route != null) _scope.deepLinks.attach(widget.appId, _route!, _navigateTo);
    }
    // Đăng ký phụ thuộc vào platform brightness để bắt thay đổi khi mode = system.
    MediaQuery.platformBrightnessOf(context);
    _syncTheme();
  }

  ThemeSpec _resolvedTheme() =>
      _themeController.value.resolve(WidgetsBinding.instance.platformDispatcher.platformBrightness);

  void _syncTheme() {
    if (!_connected) return;
    final theme = _resolvedTheme();
    if (theme == _lastSentTheme) return;
    _lastSentTheme = theme;
    _bridge.emit(BridgeEvents.themeChanged, theme.toJson());
  }

  /// Back (nút cứng, vuốt, mũi tên AppBar): hỏi mini app trước, nó tự pop
  /// dialog/route bên trong. Chỉ đóng mini app khi nó trả `handled: false`.
  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      var handled = false;
      if (_connected) {
        try {
          final result = await _bridge.request(MiniAppMethods.backPressed);
          handled = result is Map && result['handled'] == true;
        } on Object catch (e) {
          // Mini app không trả lời (treo / không hỗ trợ) -> đóng luôn, không để
          // người dùng kẹt. Không dùng webView.canGoBack()/goBack(): Flutter web
          // tự chèn entry vào history nên canGoBack gần như luôn true, và goBack
          // vào một trang đang treo thì không có tác dụng gì.
          debugPrint('[MiniApp] backPressed không được trả lời, đóng mini app: $e');
        }
      }
      if (!handled) _closeMiniApp();
    } finally {
      _handlingBack = false;
    }
  }

  void _closeMiniApp() {
    final route = _route;
    if (!mounted || route == null || !route.isActive) return;
    // Bỏ các sheet/dialog của Shell phía trên, rồi pop chính trang này.
    // router.pop() bỏ qua PopScope (khác maybePop), nên không quay lại _handleBack.
    final router = context.router;
    router.popUntil((r) => r == route);
    router.pop();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _themeController.removeListener(_syncTheme);
    _scope.config.removeListener(_onConfigChanged);
    if (_route != null) _scope.deepLinks.detach(widget.appId, _route!);
    _bridge.dispose();
    _server?.close();
    // Tạo WebView dự phòng cho lần mở sau, sau khi hiệu ứng đóng trang xong.
    final pool = _scope.webViews;
    Future<void>.delayed(const Duration(milliseconds: 500), pool.warmUp);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _app?.info;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Icon(info?.iconData ?? Icons.apps, color: theme.colorScheme.primary),
              const SizedBox(width: DsSpacing.sm),
              Flexible(child: Text(info?.name ?? widget.appId, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: DsSpacing.sm),
              if (info != null) DsBadge(label: 'web v${info.version}'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Giao diện',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => ThemeSettings.showSheet(context, _themeController),
            ),
            // Nút ✕ đóng thẳng mini app, không hỏi mini app như Back.
            IconButton(tooltip: 'Đóng mini app', icon: const Icon(Icons.close), onPressed: _closeMiniApp),
          ],
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
        ),
        body: Stack(
          children: [
            // WebView không nhận system insets (Android 15 edge-to-edge),
            // nên Shell chừa chỗ cho thanh điều hướng thay cho mini app.
            SafeArea(top: false, child: WebViewWidget(controller: _webView)),
            if (_error != null)
              Positioned.fill(
                child: ColoredBox(
                  color: theme.colorScheme.surface,
                  child: DsEmptyState(
                    icon: Icons.error_outline,
                    message: 'Không mở được mini app\n$_error',
                    action: DsButton(label: 'Đóng', onPressed: _closeMiniApp),
                  ),
                ),
              )
            else if (!_connected)
              Positioned.fill(
                child: ColoredBox(
                  color: theme.colorScheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(info?.iconData ?? Icons.apps, size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: DsSpacing.lg),
                        const SizedBox(width: 140, child: LinearProgressIndicator()),
                        const SizedBox(height: DsSpacing.sm),
                        Text('Đang khởi động ${info?.name ?? widget.appId}…', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
