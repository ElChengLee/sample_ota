import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Bridge tối giản tới Shell, chỉ dùng `dart:js_interop` của SDK.
///
/// Cùng giao thức JSON với `packages/mini_app_bridge` (Shell không phân biệt):
/// ```
/// Mini -> Shell : window.ShellBridge.postMessage(json)
/// Shell -> Mini : window.__shellDispatch(json)
/// {type: request,  id, method, params}
/// {type: response, id, result, error}
/// {type: event,    name, data}
/// ```
class ShellBridge {
  ShellBridge._();

  static final ShellBridge instance = ShellBridge._();

  static const _channel = 'ShellBridge';
  static const _dispatchFn = '__shellDispatch';

  final _pending = <String, Completer<Object?>>{};
  final _handlers = <String, Future<Object?> Function(Map<String, Object?> params)>{};
  final _eventListeners = <void Function(String name, Map<String, Object?> data)>[];
  var _seq = 0;
  var _started = false;

  /// `window.ShellBridge` chỉ có khi chạy trong WebView của Shell.
  bool get isEmbedded => globalContext.has(_channel);

  void _ensureListening() {
    if (_started || !isEmbedded) return;
    _started = true;
    globalContext[_dispatchFn] = ((JSString raw) => _onMessage(raw.toDart)).toJS;
  }

  /// Handshake. Shell chỉ ẩn màn loading sau khi nhận `init`.
  Future<Map<String, Object?>> init() async {
    _ensureListening();
    final result = await call('init');
    return result is Map ? result.cast<String, Object?>() : const {};
  }

  Future<Object?> call(String method, [Map<String, Object?> params = const {}]) {
    if (!isEmbedded) return _mock(method, params);
    final id = 'g${++_seq}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _post({'type': 'request', 'id': id, 'method': method, 'params': params});
    return completer.future;
  }

  Future<void> showToast(String message) => call('showToast', {'message': message});

  Future<void> close() => call('close');

  /// Đăng ký xử lý request Shell gọi xuống (`backPressed`, `navigate`).
  void handle(String method, Future<Object?> Function(Map<String, Object?> params) handler) {
    _ensureListening();
    _handlers[method] = handler;
  }

  void onEvent(void Function(String name, Map<String, Object?> data) listener) {
    _ensureListening();
    _eventListeners.add(listener);
  }

  void _post(Map<String, Object?> message) {
    final channel = globalContext[_channel] as JSObject;
    channel.callMethod<JSAny?>('postMessage'.toJS, jsonEncode(message).toJS);
  }

  void _onMessage(String raw) {
    final Map<String, Object?> msg;
    try {
      msg = (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object catch (e) {
      debugPrint('[ShellBridge] bad message: $e');
      return;
    }
    switch (msg['type']) {
      case 'response':
        final completer = _pending.remove(msg['id']);
        if (completer == null) return;
        final error = msg['error'];
        error != null ? completer.completeError(StateError('$error')) : completer.complete(msg['result']);
      case 'event':
        final data = msg['data'] is Map ? (msg['data'] as Map).cast<String, Object?>() : <String, Object?>{};
        for (final listener in List.of(_eventListeners)) {
          listener(msg['name'] as String? ?? '', data);
        }
      case 'request':
        _answer(msg);
    }
  }

  Future<void> _answer(Map<String, Object?> request) async {
    final id = request['id'];
    final method = request['method'];
    final handler = _handlers[method];
    final params = request['params'] is Map ? (request['params'] as Map).cast<String, Object?>() : <String, Object?>{};
    Object? result;
    String? error;
    if (handler == null) {
      error = 'Method not supported: $method';
    } else {
      try {
        result = await handler(params);
      } on Object catch (e) {
        error = e.toString();
      }
    }
    _post({'type': 'response', 'id': id, 'result': result, 'error': error});
  }

  Future<Object?> _mock(String method, Map<String, Object?> params) async {
    debugPrint('[ShellBridge] standalone mock: $method $params');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return switch (method) {
      'init' => {
          'theme': Uri.base.queryParameters,
          'user': {'id': 'dev', 'name': 'Dev User', 'phone': '0900000000'},
          'appVersion': 'dev',
          'shellVersion': 'standalone',
        },
      _ => null,
    };
  }
}

/// `localStorage` qua js_interop. Origin của mini app cố định (cổng theo appId)
/// nên dữ liệu được giữ giữa các lần mở.
abstract final class LocalStore {
  static JSObject? get _storage => globalContext['localStorage'] as JSObject?;

  static String? get(String key) {
    try {
      return _storage?.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
    } on Object {
      return null;
    }
  }

  static void set(String key, String value) {
    try {
      _storage?.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
    } on Object {
      // Bỏ qua: chỉ mất kỷ lục.
    }
  }
}
