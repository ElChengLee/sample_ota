import 'package:flutter/material.dart';

import '../tokens/ds_radius.dart';
import '../tokens/ds_spacing.dart';

enum DsButtonVariant { primary, secondary, ghost }

/// Nút chuẩn của design system. Hỗ trợ trạng thái loading và icon.
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPressed = loading ? null : this.onPressed;
    const shape = RoundedRectangleBorder(borderRadius: DsRadius.mdAll);
    const padding = EdgeInsets.symmetric(horizontal: DsSpacing.lg, vertical: DsSpacing.md);

    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == DsButtonVariant.primary ? scheme.onPrimary : scheme.primary,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (loading || icon != null) const SizedBox(width: DsSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    return switch (variant) {
      DsButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
      DsButtonVariant.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
      DsButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
    };
  }
}
