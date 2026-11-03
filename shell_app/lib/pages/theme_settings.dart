import 'package:app_theme/app_theme.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Chọn mode + brand. Thay đổi ở đây được đẩy realtime sang mini app đang mở.
class ThemeSettings extends StatelessWidget {
  const ThemeSettings({super.key, required this.controller});

  final ThemeController controller;

  static Future<void> showSheet(BuildContext context, ThemeController controller) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.xl),
        child: ThemeSettings(controller: controller),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeSpec>(
      valueListenable: controller,
      builder: (context, spec, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Sáng')),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Hệ thống'),
              ),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Tối')),
            ],
            selected: {spec.mode},
            onSelectionChanged: (s) => controller.setMode(s.first),
          ),
          const SizedBox(height: DsSpacing.md),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              for (final brand in DsBrand.values)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: brand.seed, radius: 8),
                  label: Text(brand.label),
                  selected: spec.brand == brand,
                  onSelected: (_) => controller.setBrand(brand),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
