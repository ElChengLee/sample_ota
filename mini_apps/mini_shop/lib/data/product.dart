import 'package:flutter/material.dart';

@immutable
class Product {
  const Product(this.id, this.name, this.price, this.icon);

  final String id;
  final String name;

  /// Giá theo đồng.
  final int price;
  final IconData icon;
}

const products = [
  Product('p1', 'Cà phê sữa đá', 29000, Icons.local_cafe_outlined),
  Product('p2', 'Bánh mì thịt', 25000, Icons.lunch_dining_outlined),
  Product('p3', 'Trà đào cam sả', 45000, Icons.emoji_food_beverage_outlined),
  Product('p4', 'Bánh croissant', 35000, Icons.bakery_dining_outlined),
  Product('p5', 'Nước ép cam', 39000, Icons.local_drink_outlined),
  Product('p6', 'Kem vani', 22000, Icons.icecream_outlined),
];

final _byId = {for (final product in products) product.id: product};

/// `null` nếu không có (id lấy từ URL hoặc giỏ hàng lưu từ bản cũ có thể sai).
Product? productById(String id) => _byId[id];
