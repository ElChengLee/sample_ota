import 'package:app_theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

/// Shell giả cho test: trả kết quả định sẵn, ghi lại các lần gọi.
class FakeShell implements ShellApi {
  FakeShell({
    this.user = const MiniAppUser(id: 'u1', name: 'Bình', phone: '0900000000'),
    this.payment = const PaymentSuccess('TX1'),
    this.initError,
  });

  final MiniAppUser? user;
  PaymentResult payment;
  Object? initError;

  final toasts = <String>[];
  final links = <Uri>[];
  final payments = <int>[];
  var closed = 0;

  @override
  bool get isEmbedded => true;

  @override
  final ValueNotifier<ThemeSpec> theme = ValueNotifier(const ThemeSpec());

  @override
  Future<MiniAppContext> init() async {
    if (initError case final error?) throw error;
    return MiniAppContext(user: user, appVersion: 'test', shellVersion: 'fake');
  }

  @override
  Future<PaymentResult> requestPayment({
    required int amount,
    required String orderId,
    required String description,
  }) async {
    payments.add(amount);
    return payment;
  }

  @override
  Future<bool> openDeepLink(Uri link) async {
    links.add(link);
    return true;
  }

  @override
  Future<void> showToast(String message) async => toasts.add(message);

  @override
  Future<void> close() async => closed++;

  @override
  void setBackHandler(Future<bool> Function() handler) {}

  @override
  void setNavigateHandler(Future<void> Function(String path) handler) {}
}
