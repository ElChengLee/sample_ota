import 'package:flutter_test/flutter_test.dart';
import 'package:mini_shop/data/key_value_store.dart';
import 'package:mini_shop/state/cart_controller.dart';
import 'package:mini_shop/utils/format.dart';

void main() {
  CartController cartWith(String? stored) =>
      CartController(InMemoryKeyValueStore({CartController.storageKey: ?stored}));

  test('thêm, tính tổng, lưu lại và đọc ra ở lần mở sau', () {
    final store = InMemoryKeyValueStore();
    final cart = CartController(store)
      ..add('p1')
      ..add('p1')
      ..add('p3');
    expect(cart.count, 3);
    expect(cart.total, 29000 * 2 + 45000);

    final reopened = CartController(store);
    expect(reopened.value, {'p1': 2, 'p3': 1});
  });

  test('sản phẩm đã bị bỏ ở bản mới: bỏ qua, không crash', () {
    final cart = cartWith('{"p1": 1, "p_da_xoa": 3}');
    expect(cart.value, {'p1': 1});
    expect(cart.total, 29000);
  });

  test('dữ liệu hỏng hoặc sai kiểu: giỏ trống, không crash', () {
    expect(cartWith('{không phải json').value, isEmpty);
    expect(cartWith('[1, 2]').value, isEmpty);
    expect(cartWith('{"p1": "2", "p2": -1, "p3": 1.5, "p4": 2}').value, {'p4': 2});
  });

  test('không thêm id không tồn tại; clear xoá cả bản lưu', () {
    final store = InMemoryKeyValueStore();
    final cart = CartController(store)
      ..add('khong_co')
      ..add('p2');
    expect(cart.value, {'p2': 1});
    cart.clear();
    expect(CartController(store).value, isEmpty);
  });

  test('formatVnd', () {
    expect(formatVnd(0), '0đ');
    expect(formatVnd(25000), '25.000đ');
    expect(formatVnd(1234567), '1.234.567đ');
  });
}
