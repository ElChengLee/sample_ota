import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

typedef BridgeHandler = Future<Object?> Function(Map<String, Object?> params);

/// Phía Shell: nhận request từ Mini App, gọi handler tương ứng và trả response;
/// đồng thời có thể [request] ngược xuống Mini App (vd [MiniAppMethods.backPressed]).
///
/// Không phụ thuộc WebView: Shell chỉ cần nối [runJavaScript] vào controller
/// và gọi [handleIncoming] khi JavaScriptChannel nhận được message.
class ShellBridgeHost {
  ShellBridgeHost({required this.runJavaScript, required this._handlers, this.hasPermission});

  final Future<void> Function(String script) runJavaScript;
  final Map<String, BridgeHandler> _handlers;

  /// Mini app hiện tại có quyền [permission] không (xem [BridgePermissions]).
  /// `null` = không kiểm tra. Method cần quyền mà thiếu thì trả lỗi, không gọi handler.
  final bool Function(String permission)? hasPermission;

  final _pending = <String, Completer<Object?>>{};
  var _seq = 0;
  var _disposed = false;

  Future<void> handleIncoming(String raw) async {
    final BridgeMessage message;
    try {
      message = BridgeMessage.decode(raw);
    } on Object catch (e) {
      debugPrint('[ShellBridge] invalid message: $e');
      return;
    }
    switch (message) {
      case BridgeRequest():
        await _send(await _handle(message));
      case BridgeResponse(:final id, :final error, :final result):
        final completer = _pending.remove(id);
        if (completer == null) return;
        error != null ? completer.completeError(BridgeException(error)) : completer.complete(result);
      case BridgeEvent():
        break;
    }
  }

  /// Gọi method do Mini App cài đặt. Ném [TimeoutException] nếu Mini App
  /// không trả lời kịp (chưa boot xong, bị treo...) để Shell có đường lui.
  Future<Object?> request(
    String method, {
    Map<String, Object?> params = const {},
    Duration timeout = const Duration(milliseconds: 800),
  }) {
    if (_disposed) return Future.error(StateError('Bridge disposed'));
    final id = 's${++_seq}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _send(BridgeRequest(id: id, method: method, params: params));
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('Mini App không trả lời $method', timeout);
    });
  }

  Future<void> emit(String event, [Map<String, Object?> data = const {}]) =>
      _send(BridgeEvent(name: event, data: data));

  /// Gọi khi WebView bị huỷ: mọi message gửi sau đó bị bỏ qua thay vì
  /// runJavaScript lên controller đã chết.
  void dispose() {
    _disposed = true;
    for (final completer in _pending.values) {
      completer.completeError(StateError('Bridge disposed'));
    }
    _pending.clear();
  }

  Future<BridgeResponse> _handle(BridgeRequest request) async {
    final handler = _handlers[request.method];
    if (handler == null) {
      return BridgeResponse(id: request.id, error: 'Method not supported: ${request.method}');
    }
    final permission = BridgePermissions.requiredFor(request.method);
    if (permission != null && hasPermission != null && !hasPermission!(permission)) {
      debugPrint('[ShellBridge] từ chối ${request.method}: thiếu quyền "$permission"');
      return BridgeResponse(id: request.id, error: 'Permission denied: $permission');
    }
    try {
      return BridgeResponse(id: request.id, result: await handler(request.params));
    } on Object catch (e) {
      return BridgeResponse(id: request.id, error: e.toString());
    }
  }

  Future<void> _send(BridgeMessage message) async {
    if (_disposed) return;
    // jsonEncode lần 2 để có một JS string literal an toàn (escape quote, unicode...).
    final literal = jsonEncode(message.encode());
    try {
      await runJavaScript('window.$kMiniAppDispatchFn && window.$kMiniAppDispatchFn($literal);');
    } on Object catch (e) {
      debugPrint('[ShellBridge] send failed: $e');
    }
  }
}
