import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'theme_spec.dart';

/// Build [ThemeData] từ design tokens. Shell và Mini App gọi cùng hàm này.
abstract final class AppTheme {
  static ThemeData light(ThemeSpec spec) => build(spec.brand, Brightness.light);

  static ThemeData dark(ThemeSpec spec) => build(spec.brand, Brightness.dark);

  static ThemeData build(DsBrand brand, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: brand.seed, brightness: brightness);
    // Font đóng gói trong design_system: Flutter web không phải tải Roboto từ
    // fonts.gstatic.com, chạy được offline và giống nhau trên mọi WebView.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: DsTypography.fontFamily,
      package: DsTypography.fontPackage,
    );

    return base.copyWith(
      textTheme: base.textTheme.merge(DsTypography.textTheme).apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.mdAll),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(DsRadius.lg)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
