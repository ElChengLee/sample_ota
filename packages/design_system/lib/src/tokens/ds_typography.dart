import 'package:flutter/material.dart';

/// Type scale dùng để build [TextTheme] trong `app_theme`.
abstract final class DsTypography {
  /// Font đóng gói trong package này (xem pubspec.yaml).
  static const fontFamily = 'Roboto';
  static const fontPackage = 'design_system';

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
  );
}
