import 'dart:async';

import 'package:app_theme/app_theme.dart';
import 'package:flutter/foundation.dart';

import 'protocol.dart';
import 'shell_api.dart';
import 'transport/transport_stub.dart'
    if (dart.library.js_interop) 'transport/transport_web.dart' as transport;

/// Phía Mini App: gọi method lên Shell và nhận event từ Shell.
///
/// Khi chạy độc lập (`flutter run -d chrome`, không có Shell) bridge tự chuyển
/// sang chế độ mock để dev UI mà không cần build/tải vào Shell.
class MiniAppBridge implements ShellApi {
  MiniAppBridge._();

  /// Shell không trả lời trong thời gian này thì request báo lỗi, không treo
  /// mãi. Không áp dụng cho method chờ người dùng thao tác (thanh toán).
  static const defaultTimeout = Duration(seconds: 15);

  static final MiniAppBridge instance = MiniAppBridge._();

  /// Theme hiện tại. Giá trị đầu đọc từ query `?mode=&brand=` của URL để
  /// frame đầu tiên đã đúng màu, trước khi handshake xong.
  @override
  final ValueNotifier<ThemeSpec> theme = ValueNotifier(
    ThemeSpec.fromJson(Uri.base.queryParameters),
  );

  final _pending = <String, Completer<Object?>>{};
  final _handlers = <String, Future<Object?> Function(Map<String, Object?> params)>{};
  final _events = StreamController<BridgeEvent>.broadcast();
  var _seq = 0;
  var _listening = false;

  @override
  bool get isEmbedded => transport.hasShell;

  Stream<BridgeEvent> get events => _events.stream;

  @override
  Future<MiniAppContext> init() async {
    if (!_listening) {
      transport.listenFromShell(_onMessage);
      _listening = true;
    }
    final result = (await call(BridgeMethods.init) as Map).cast<String, Object?>();
    theme.value = ThemeSpec.fromJson((result['theme'] as Map).cast());
    return MiniAppContext(
      // Shell chỉ gửi `user` khi mini app có quyền BridgePermissions.userInfo.
      user: result['user'] is Map ? MiniAppUser.fromJson((result['user'] as Map).cast()) : null,
      appVersion: result['appVersion'] as String? ?? '-',
      shellVersion: result['shellVersion'] as String? ?? '-',
    );
  }

  /// Gọi method [method] của Shell (mức thấp, trả JSON thô). Ném
  /// [BridgeException] khi Shell trả lỗi hoặc quá [defaultTimeout]. Nên dùng
  /// các hàm có kiểu của [ShellApi] thay vì gọi trực tiếp.
  Future<Object?> call(String method, [Map<String, Object?> params = const {}]) {
    if (!isEmbedded) return _standalone(method, params);

    final id = '${++_seq}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    transport.postToShell(BridgeRequest(id: id, method: method, params: params).encode());
    if (method == BridgeMethods.requestPayment) return completer.future;
    return completer.future.timeout(defaultTimeout, onTimeout: () {
      _pending.remove(id);
      throw BridgeException('Shell không phản hồi $method sau ${defaultTimeout.inSeconds}s');
    });
  }

  @override
  Future<PaymentResult> requestPayment({
    required int amount,
    required String orderId,
    required String description,
  }) async {
    try {
      final result = await call(BridgeMethods.requestPayment, {
        'amount': amount,
        'orderId': orderId,
        'description': description,
      });
      return switch (result) {
        {'status': 'success', 'transactionId': final String id} => PaymentSuccess(id),
        {'status': 'cancelled'} => const PaymentCancelled(),
        _ => PaymentFailed('Phản hồi thanh toán không hợp lệ: $result'),
      };
    } on BridgeException catch (e) {
      return PaymentFailed(e.message, permissionDenied: e.isPermissionDenied);
    }
  }

  @override
  Future<void> showToast(String message) => _fireAndForget(BridgeMethods.showToast, {'message': message});

  @override
  Future<void> close() => _fireAndForget(BridgeMethods.close);

  /// Nhờ Shell mở deep link (xem [SuperAppLinks]). Trả `false` nếu Shell từ
  /// chối (link sai, bị chặn, thiếu quyền) hoặc đang chạy standalone.
  @override
  Future<bool> openDeepLink(Uri url) async {
    try {
      final result = await call(BridgeMethods.openDeepLink, {'url': '$url'});
      return result is Map && result['opened'] == true;
    } on BridgeException catch (e) {
      debugPrint('[MiniAppBridge] openDeepLink $url thất bại: ${e.message}');
      return false;
    }
  }

  Future<void> _fireAndForget(String method, [Map<String, Object?> params = const {}]) async {
    try {
      await call(method, params);
    } on BridgeException catch (e) {
      debugPrint('[MiniAppBridge] $method thất bại: ${e.message}');
    }
  }

  /// [handler] điều hướng tới route `path` do Shell gửi xuống (deep link vào
  /// mini app đang mở). Ném lỗi nếu không có route đó, Shell sẽ báo người dùng.
  @override
  void setNavigateHandler(Future<void> Function(String path) handler) {
    registerHandler(MiniAppMethods.navigate, (params) async {
      await handler(params['path'] as String? ?? '/');
      return null;
    });
  }

  /// Đăng ký xử lý một method mà Shell gọi xuống ([MiniAppMethods]).
  void registerHandler(String method, Future<Object?> Function(Map<String, Object?> params) handler) {
    _handlers[method] = handler;
  }

  /// [handler] trả `true` nếu Mini App đã tự xử lý Back (vd `navigator.maybePop()`),
  /// `false` để Shell đóng Mini App. Không đăng ký thì Shell luôn đóng.
  @override
  void setBackHandler(Future<bool> Function() handler) {
    registerHandler(MiniAppMethods.backPressed, (_) async => {'handled': await handler()});
  }

  Future<void> _answer(BridgeRequest request) async {
    final handler = _handlers[request.method];
    BridgeResponse response;
    if (handler == null) {
      response = BridgeResponse(id: request.id, error: 'Method not supported: ${request.method}');
    } else {
      try {
        response = BridgeResponse(id: request.id, result: await handler(request.params));
      } on Object catch (e) {
        response = BridgeResponse(id: request.id, error: e.toString());
      }
    }
    transport.postToShell(response.encode());
  }

  void _onMessage(String raw) {
    final message = BridgeMessage.decode(raw);
    switch (message) {
      case BridgeResponse(:final id, :final error, :final result):
        final completer = _pending.remove(id);
        if (completer == null) return;
        error != null ? completer.completeError(BridgeException(error)) : completer.complete(result);
      case BridgeEvent(:final name, :final data):
        if (name == BridgeEvents.themeChanged) theme.value = ThemeSpec.fromJson(data);
        _events.add(message);
      case BridgeRequest():
        _answer(message);
    }
  }

  Future<Object?> _standalone(String method, Map<String, Object?> params) async {
    debugPrint('[MiniAppBridge] standalone mock: $method $params');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return switch (method) {
      BridgeMethods.init => {
          'theme': theme.value.toJson(),
          'user': const MiniAppUser(id: 'dev', name: 'Dev User', phone: '0900000000').toJson(),
          'appVersion': 'dev',
          'shellVersion': 'standalone',
        },
      BridgeMethods.requestPayment => {'status': 'success', 'transactionId': 'MOCK-${DateTime.now().millisecondsSinceEpoch}'},
      _ => null,
    };
  }
}
