import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:mini_shop/app.dart';
import 'package:mini_shop/data/key_value_store.dart';
import 'package:mini_shop/router/app_router.dart';
import 'package:mini_shop/state/cart_controller.dart';

import 'fake_shell.dart';

void main() {
  late FakeShell shell;
  late AppRouter router;
  late CartController cart;

  Future<void> pumpApp(WidgetTester tester, {FakeShell? fake}) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    shell = fake ?? FakeShell();
    router = AppRouter();
    cart = CartController(InMemoryKeyValueStore());
    await tester.pumpWidget(MiniShopApp(shell: shell, router: router, cart: cart));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện tên user từ handshake', (tester) async {
    await pumpApp(tester);
    expect(find.text('Xin chào, Bình'), findsOneWidget);
  });

  testWidgets('không có quyền userInfo: không crash, chào chung', (tester) async {
    await pumpApp(tester, fake: FakeShell(user: null));
    expect(find.text('Xin chào'), findsOneWidget);
    expect(find.textContaining('chưa được cấp quyền'), findsOneWidget);
  });

  testWidgets('handshake lỗi: báo lỗi, thử lại được', (tester) async {
    await pumpApp(tester, fake: FakeShell(initError: const BridgeException('timeout')));
    expect(find.textContaining('Không kết nối được Shell'), findsOneWidget);
    shell.initError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, Bình'), findsOneWidget);
  });

  testWidgets('thêm vào giỏ rồi thanh toán thành công: giỏ trống, có toast', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Thêm vào giỏ').first);
    await tester.pumpAndSettle();
    expect(find.text('1 sản phẩm'), findsOneWidget);
    expect(find.text('29.000đ'), findsWidgets);

    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();
    expect(shell.payments, [29000]);
    expect(cart.count, 0);
    expect(shell.toasts.single, contains('TX1'));
    expect(find.text('Thanh toán'), findsNothing);
  });

  testWidgets('thiếu quyền thanh toán: báo rõ, giữ nguyên giỏ', (tester) async {
    await pumpApp(tester, fake: FakeShell(payment: const PaymentFailed('Permission denied: payment', permissionDenied: true)));
    await tester.tap(find.byTooltip('Thêm vào giỏ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();
    expect(find.text('Mini Shop chưa được cấp quyền thanh toán'), findsOneWidget);
    expect(cart.count, 1);
  });

  testWidgets('Shell điều hướng vào màn con, Back về danh sách', (tester) async {
    await pumpApp(tester);
    await router.navigateFromShell('/product/p3');
    await tester.pumpAndSettle();
    expect(find.text('Trà đào cam sả'), findsWidgets);
    expect(find.text('45.000đ'), findsOneWidget);

    expect(await router.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Menu hôm nay'), findsOneWidget);
    // Ở màn gốc: trả false để Shell đóng mini app.
    expect(await router.maybePop(), isFalse);
  });

  testWidgets('route không tồn tại thì báo lỗi cho Shell', (tester) async {
    await pumpApp(tester);
    await expectLater(router.navigateFromShell('/khong-ton-tai'), throwsArgumentError);
  });
}
