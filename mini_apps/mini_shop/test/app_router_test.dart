import 'package:flutter_test/flutter_test.dart';
import 'package:mini_shop/router/app_router.dart';

void main() {
  final router = AppRouter();

  List<String>? names(String path) => router.stackFor(Uri.parse(path))?.map((r) => r.routeName).toList();

  test('màn gốc', () {
    expect(names('/'), [ShopRoute.name]);
    expect(names(''), [ShopRoute.name]);
  });

  test('màn con luôn có Shop ở dưới để Back về danh sách', () {
    final stack = router.stackFor(Uri.parse('/product/p2'))!;
    expect(stack.map((r) => r.routeName), [ShopRoute.name, ProductDetailRoute.name]);
    expect(stack.last.rawPathParams['productId'], 'p2');
  });

  test('path không có route thì null (Shell báo lỗi cho người dùng)', () {
    expect(names('/khong-ton-tai'), isNull);
    expect(names('/product'), isNull);
    expect(names('/product/p1/review'), isNull);
  });
}
