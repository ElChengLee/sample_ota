import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/key_value_store.dart';
import '../data/product.dart';

/// Giỏ hàng: `productId -> số lượng`, lưu vào [KeyValueStore] để mở lại mini
/// app vẫn còn.
///
/// Dữ liệu lưu sống qua các bản cập nhật mini app, nên khi đọc phải chịu được
/// dữ liệu hỏng hoặc sản phẩm đã bị bỏ ở bản mới: bỏ qua phần sai, không crash.
class CartController extends ValueNotifier<Map<String, int>> {
  CartController(this._store, {this.findProduct = productById}) : super(const {}) {
    value = _load();
  }

  static const storageKey = 'mini_shop.cart';

  final KeyValueStore _store;
  final Product? Function(String id) findProduct;

  int get count => value.values.fold(0, (a, b) => a + b);

  int get total => value.entries.fold(0, (sum, e) => sum + (findProduct(e.key)?.price ?? 0) * e.value);

  int quantityOf(String productId) => value[productId] ?? 0;

  void add(String productId) {
    if (findProduct(productId) == null) return;
    _set({...value, productId: quantityOf(productId) + 1});
  }

  void clear() => _set(const {});

  Map<String, int> _load() {
    final raw = _store.read(storageKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw FormatException('không phải object', raw);
      return Map.unmodifiable({
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is int && value > 0 && findProduct(key) != null) key: value,
      });
    } on FormatException catch (e) {
      debugPrint('[Cart] dữ liệu giỏ hàng hỏng, bắt đầu giỏ trống: $e');
      return const {};
    }
  }

  void _set(Map<String, int> cart) {
    value = Map.unmodifiable(cart);
    _store.write(storageKey, jsonEncode(cart));
  }
}
