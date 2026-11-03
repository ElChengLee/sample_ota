import 'dart:convert';

/// Tên JavaScriptChannel mà Shell inject vào WebView (`window.ShellBridge.postMessage`).
const String kShellChannelName = 'ShellBridge';

/// Hàm global mà Mini App đăng ký để nhận message từ Shell.
const String kMiniAppDispatchFn = '__shellDispatch';

/// Các method Mini App có thể gọi lên Shell.
abstract final class BridgeMethods {
  /// Handshake: trả về theme, user, thông tin app.
  static const init = 'init';
  static const getUserInfo = 'getUserInfo';
  static const showToast = 'showToast';
  static const requestPayment = 'requestPayment';
  static const close = 'close';

  /// `{url}`: nhờ Shell mở một [SuperAppLinks] (màn của Shell, mini app khác,
  /// hoặc màn khác của chính mini app). Trả `{opened: bool}`.
  static const openDeepLink = 'openDeepLink';
}

/// Quyền bridge một mini app phải khai báo trong `mini_app.json` (`"permissions"`).
///
/// Manifest được ký nên danh sách quyền không bị sửa trên đường truyền. Method
/// không có trong [requiredFor] (init, showToast, close) thì app nào cũng gọi được.
abstract final class BridgePermissions {
  /// Thông tin user: `getUserInfo` và trường `user` trong kết quả `init`.
  static const userInfo = 'userInfo';

  /// `requestPayment`: mở sheet thanh toán native.
  static const payment = 'payment';

  /// `openDeepLink`: điều hướng Shell / mở mini app khác.
  static const deepLink = 'deepLink';

  static const all = {userInfo, payment, deepLink};

  /// Quyền cần có để gọi [method], `null` nếu method không cần quyền.
  static String? requiredFor(String method) => switch (method) {
        BridgeMethods.getUserInfo => userInfo,
        BridgeMethods.requestPayment => payment,
        BridgeMethods.openDeepLink => deepLink,
        _ => null,
      };
}

/// Các method Shell gọi xuống Mini App (Mini App trả lời bằng [BridgeResponse]).
abstract final class MiniAppMethods {
  /// Người dùng bấm Back (nút cứng / vuốt / mũi tên AppBar).
  /// Mini App trả `{handled: true}` nếu đã tự pop (route, dialog, sheet),
  /// `false` nếu đang ở màn gốc -> Shell đóng mini app.
  static const backPressed = 'backPressed';

  /// `{path}`: deep link tới mini app đang mở. Mini App tự điều hướng router
  /// của nó tới `path` (vd `/product/p2`) thay vì Shell load lại WebView.
  static const navigate = 'navigate';
}

/// Định dạng deep link chung cho hệ điều hành, Shell và mini app:
/// ```
/// superapp://open/                                    Home của Shell
/// superapp://open/mini-app/<appId>?path=/product/p2   mở mini app, vào thẳng route `path`
/// ```
abstract final class SuperAppLinks {
  static const scheme = 'superapp';
  static const host = 'open';

  static Uri home() => Uri(scheme: scheme, host: host, path: '/');

  static Uri miniApp(String appId, {String? path}) => Uri(
        scheme: scheme,
        host: host,
        path: '/mini-app/$appId',
        queryParameters: path == null ? null : {'path': path},
      );

  /// Mini app native biên dịch sẵn trong Shell (không OTA).
  static Uri nativeApp(String appId) => Uri(scheme: scheme, host: host, path: '/native/$appId');
}

/// Các event Shell chủ động đẩy xuống Mini App.
abstract final class BridgeEvents {
  static const themeChanged = 'themeChanged';
}

sealed class BridgeMessage {
  const BridgeMessage();

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  static BridgeMessage decode(String raw) {
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    return switch (json['type']) {
      'request' => BridgeRequest(
          id: json['id'] as String,
          method: json['method'] as String,
          params: _map(json['params']),
        ),
      'response' => BridgeResponse(
          id: json['id'] as String,
          result: json['result'],
          error: json['error'] as String?,
        ),
      'event' => BridgeEvent(name: json['name'] as String, data: _map(json['data'])),
      final type => throw FormatException('Unknown bridge message type: $type'),
    };
  }

  static Map<String, Object?> _map(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const {};
}

/// Lời gọi có trả lời. Chủ yếu Mini App -> Shell, ngoài ra Shell -> Mini App cho [MiniAppMethods].
class BridgeRequest extends BridgeMessage {
  const BridgeRequest({required this.id, required this.method, this.params = const {}});

  final String id;
  final String method;
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() => {'type': 'request', 'id': id, 'method': method, 'params': params};
}

/// Trả lời cho [BridgeRequest] cùng `id` (theo chiều ngược lại).
class BridgeResponse extends BridgeMessage {
  const BridgeResponse({required this.id, this.result, this.error});

  final String id;
  final Object? result;
  final String? error;

  @override
  Map<String, Object?> toJson() => {'type': 'response', 'id': id, 'result': result, 'error': error};
}

/// Shell -> Mini App, thông báo một chiều.
class BridgeEvent extends BridgeMessage {
  const BridgeEvent({required this.name, this.data = const {}});

  final String name;
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => {'type': 'event', 'name': name, 'data': data};
}

/// Lỗi trả về từ Shell (handler throw hoặc method không tồn tại).
class BridgeException implements Exception {
  const BridgeException(this.message);

  final String message;

  /// Shell từ chối vì mini app thiếu quyền (xem [BridgePermissions]).
  bool get isPermissionDenied => message.startsWith('Permission denied');

  @override
  String toString() => 'BridgeException: $message';
}
