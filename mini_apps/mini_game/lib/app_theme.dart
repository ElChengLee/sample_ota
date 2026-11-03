import 'package:flutter/material.dart';

/// Theme do Shell điều khiển: `{mode: light|dark|system, seed: RRGGBB}`.
///
/// Không dùng package `app_theme` chung. Shell gửi kèm màu `seed` của brand nên
/// mini app không cần biết bảng màu từng brand: Shell thêm/đổi brand thì app này
/// tự đúng màu mà không phải build lại.
@immutable
class GameTheme {
  const GameTheme({this.mode = ThemeMode.system, this.seed = _fallbackSeed});

  /// Chỉ dùng khi chạy standalone mà URL không có `seed`.
  static const _fallbackSeed = Color(0xFF1565C0);

  final ThemeMode mode;
  final Color seed;

  factory GameTheme.fromJson(Map<String, Object?> json) {
    final hex = int.tryParse('${json['seed'] ?? ''}', radix: 16);
    return GameTheme(
      mode: ThemeMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => ThemeMode.system),
      seed: hex == null ? _fallbackSeed : Color(0xFF000000 | hex),
    );
  }

  ThemeData build(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
        fontFamily: 'Roboto', // đóng gói trong fonts/, xem pubspec.yaml
      );

  @override
  bool operator ==(Object other) => other is GameTheme && other.mode == mode && other.seed == seed;

  @override
  int get hashCode => Object.hash(mode, seed);
}
