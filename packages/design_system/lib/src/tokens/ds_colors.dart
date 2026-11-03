import 'package:flutter/material.dart';

/// Bảng màu thương hiệu. Shell chọn 1 brand, Mini App nhận brand qua bridge.
enum DsBrand {
  ocean('Ocean', Color(0xFF1565C0)),
  forest('Forest', Color(0xFF2E7D32)),
  sunset('Sunset', Color(0xFFE65100)),
  grape('Grape', Color(0xFF6A1B9A));

  const DsBrand(this.label, this.seed);

  final String label;
  final Color seed;

  static DsBrand fromName(String? name) =>
      DsBrand.values.firstWhere((b) => b.name == name, orElse: () => DsBrand.ocean);
}

/// Màu ngữ nghĩa không phụ thuộc brand.
abstract final class DsColors {
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF9A825);
  static const danger = Color(0xFFC62828);
  static const info = Color(0xFF0277BD);
}
