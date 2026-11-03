import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Mô tả theme ở dạng dữ liệu thuần, có thể gửi qua bridge sang Mini App.
@immutable
class ThemeSpec {
  const ThemeSpec({this.mode = ThemeMode.system, this.brand = DsBrand.ocean});

  final ThemeMode mode;
  final DsBrand brand;

  ThemeSpec copyWith({ThemeMode? mode, DsBrand? brand}) =>
      ThemeSpec(mode: mode ?? this.mode, brand: brand ?? this.brand);

  /// Chốt [ThemeMode.system] thành light/dark theo [platformBrightness].
  /// Dùng trước khi gửi sang Mini App vì WebView không biết shell đang ở mode nào.
  ThemeSpec resolve(Brightness platformBrightness) {
    if (mode != ThemeMode.system) return this;
    return copyWith(mode: platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
  }

  /// `seed` (hex RRGGBB) cho mini app không dùng package chung: tự dựng
  /// `ColorScheme.fromSeed` mà không cần biết bảng màu của từng brand.
  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'brand': brand.name,
        'seed': (brand.seed.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
      };

  factory ThemeSpec.fromJson(Map<String, Object?> json) => ThemeSpec(
        mode: ThemeMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => ThemeMode.system,
        ),
        brand: DsBrand.fromName(json['brand'] as String?),
      );

  @override
  bool operator ==(Object other) => other is ThemeSpec && other.mode == mode && other.brand == brand;

  @override
  int get hashCode => Object.hash(mode, brand);
}
