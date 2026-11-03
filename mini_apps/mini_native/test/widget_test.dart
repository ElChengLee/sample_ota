import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_native/mini_native.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeHost implements MiniNativeHost {
  final toasts = <String>[];
  var closed = 0;

  @override
  String get name => 'Test host';
  @override
  bool get embedded => true;
  @override
  MiniNativeUser? get user => (id: 'u1', name: 'Tester');
  @override
  void showToast(String message) => toasts.add(message);
  @override
  Future<bool> requestPayment({required int amount, required String description}) async => true;
  @override
  Future<bool> openDeepLink(Uri link) async => true;
  @override
  void close() => closed++;
}

void main() {
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  testWidgets('Back pop màn bên trong trước, hết màn mới đóng mini app', (tester) async {
    final host = _FakeHost();
    await tester.pumpWidget(MaterialApp(home: MiniNativeApp(host: host)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tester (u1)'), findsOneWidget);
    expect(find.textContaining('Số lần mở mini app: 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Mở màn chi tiết'), 200);
    await tester.ensureVisible(find.text('Mở màn chi tiết'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở màn chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết #1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết #1'), findsNothing);
    expect(host.closed, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(host.closed, 1);
  });
}
