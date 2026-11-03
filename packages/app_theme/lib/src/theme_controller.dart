import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'theme_spec.dart';

/// Nguồn sự thật về theme. Lắng nghe để rebuild MaterialApp hoặc đẩy sang Mini App.
class ThemeController extends ValueNotifier<ThemeSpec> {
  ThemeController([super.value = const ThemeSpec()]);

  void setMode(ThemeMode mode) => value = value.copyWith(mode: mode);

  void setBrand(DsBrand brand) => value = value.copyWith(brand: brand);
}
