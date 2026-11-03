import 'package:app_theme/app_theme.dart';
import 'package:flutter/foundation.dart';

/// Người dùng đang đăng nhập ở Shell.
@immutable
class MiniAppUser {
  const MiniAppUser({required this.id, required this.name, required this.phone});

  final String id;
  final String name;
  final String phone;

  factory MiniAppUser.fromJson(Map<String, Object?> json) => MiniAppUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'phone': phone};
}

/// Kết quả handshake với Shell.
@immutable
class MiniAppContext {
  const MiniAppContext({required this.user, required this.appVersion, required this.shellVersion});

  /// `null` khi mini app không có quyền `userInfo` (Shell không gửi user).
  final MiniAppUser? user;
  final String appVersion;
  final String shellVersion;
}

/// Kết quả [ShellApi.requestPayment].
sealed class PaymentResult {
  const PaymentResult();
}

final class PaymentSuccess extends PaymentResult {
  const PaymentSuccess(this.transactionId);

  final String transactionId;
}

/// Người dùng đóng sheet thanh toán.
final class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}

/// Không thanh toán được: thiếu quyền `payment`, Shell không phản hồi, lỗi khác.
final class PaymentFailed extends PaymentResult {
  const PaymentFailed(this.reason, {this.permissionDenied = false});

  final String reason;
  final bool permissionDenied;
}

/// Những gì mini app cần từ Shell, dạng hàm Dart có kiểu.
///
/// [MiniAppBridge] là bản thật (JSON qua JS bridge). Mini app nên phụ thuộc
/// vào interface này thay vì `MiniAppBridge.instance`, để test được với bản giả.
///
/// Quy ước lỗi: các hàm "gửi đi rồi thôi" ([openDeepLink], [showToast],
/// [close]) không ném lỗi; [requestPayment] trả [PaymentFailed] thay vì ném.
/// Chỉ [init] ném lỗi (không handshake được thì mini app không chạy được).
abstract interface class ShellApi {
  /// `true` khi chạy trong Shell, `false` khi chạy độc lập (mock).
  bool get isEmbedded;

  /// Theme do Shell điều khiển, đổi khi người dùng đổi theme ở Shell.
  ValueListenable<ThemeSpec> get theme;

  Future<MiniAppContext> init();

  Future<PaymentResult> requestPayment({required int amount, required String orderId, required String description});

  /// `false` nếu Shell không mở (link sai, bị chặn, thiếu quyền `deepLink`).
  Future<bool> openDeepLink(Uri link);

  Future<void> showToast(String message);

  Future<void> close();

  /// [handler] trả `true` nếu mini app đã tự xử lý Back, `false` để Shell đóng mini app.
  void setBackHandler(Future<bool> Function() handler);

  /// [handler] điều hướng tới `path` do Shell gửi xuống; ném lỗi nếu không có route.
  void setNavigateHandler(Future<void> Function(String path) handler);
}
