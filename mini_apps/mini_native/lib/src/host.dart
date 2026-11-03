import 'package:flutter/material.dart';

/// Người dùng do host cung cấp.
typedef MiniNativeUser = ({String id, String name});

/// API mà host (Shell hoặc runner standalone) cung cấp cho mini app native.
///
/// Đây là bản tương đương của JS bridge, nhưng gọi hàm Dart trực tiếp: mini app
/// được biên dịch cùng Shell nên không cần serialize JSON hay kiểm tra quyền.
abstract interface class MiniNativeHost {
  /// Tên host để hiển thị, vd `Super App Shell v1.0.0`.
  String get name;

  /// `true` khi chạy bên trong Shell, `false` khi chạy standalone.
  bool get embedded;

  MiniNativeUser? get user;

  void showToast(String message);

  /// Mở UI thanh toán của host. Trả `true` nếu người dùng xác nhận.
  Future<bool> requestPayment({required int amount, required String description});

  /// Mở một deep link `superapp://open/...`. Trả `false` nếu host không mở được.
  Future<bool> openDeepLink(Uri link);

  /// Đóng mini app.
  void close();
}

/// Host giả khi chạy `flutter run` trực tiếp trong `mini_apps/mini_native`.
class StandaloneHost implements MiniNativeHost {
  StandaloneHost(this.messengerKey, this.navigatorKey);

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  String get name => 'Standalone (mock host)';

  @override
  bool get embedded => false;

  @override
  MiniNativeUser? get user => (id: 'mock', name: 'Người dùng thử');

  @override
  void showToast(String message) =>
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text('[mock] $message')));

  @override
  Future<bool> requestPayment({required int amount, required String description}) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán (mock)'),
        content: Text('$description\n$amountđ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Future<bool> openDeepLink(Uri link) async {
    showToast('Standalone không mở được $link');
    return false;
  }

  @override
  void close() => showToast('Standalone: không có gì để đóng');
}
