import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../protocol.dart';

/// `window.ShellBridge` chỉ tồn tại khi chạy trong WebView của Shell.
bool get hasShell => globalContext.has(kShellChannelName);

void postToShell(String message) {
  final channel = globalContext[kShellChannelName] as JSObject;
  channel.callMethod<JSAny?>('postMessage'.toJS, message.toJS);
}

void listenFromShell(void Function(String raw) onMessage) {
  globalContext[kMiniAppDispatchFn] = ((JSString raw) => onMessage(raw.toDart)).toJS;
}
