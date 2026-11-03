/// Giao thức giao tiếp Shell <-> Mini App.
///
/// ```
///  Mini App (Flutter web, trong WebView)            Shell (Flutter native)
///  ─────────────────────────────────────            ──────────────────────
///  MiniAppBridge.call('requestPayment') ──JSON──▶  JavaScriptChannel "ShellBridge"
///                                                   └▶ ShellBridgeHost.handleIncoming
///  window.__shellDispatch(json)        ◀──JSON──   runJavaScript(...)  (response/event)
/// ```
///
/// - Mini App dùng [ShellApi] (bản thật: [MiniAppBridge]).
/// - Shell dùng [ShellBridgeHost] (không phụ thuộc WebView cụ thể).
library;

export 'src/mini_app_bridge_client.dart';
export 'src/protocol.dart';
export 'src/shell_api.dart';
export 'src/shell_bridge_host.dart';
