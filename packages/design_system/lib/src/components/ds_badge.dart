import 'package:flutter/material.dart';

import '../tokens/ds_radius.dart';
import '../tokens/ds_spacing.dart';

/// Nhãn nhỏ dạng pill (vd: version, trạng thái cài đặt).
class DsBadge extends StatelessWidget {
  const DsBadge({super.key, required this.label, this.color});

  final String label;

  /// Mặc định là `colorScheme.primary`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xxs),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: base),
      ),
    );
  }
}
