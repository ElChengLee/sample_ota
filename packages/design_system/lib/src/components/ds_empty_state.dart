import 'package:flutter/material.dart';

import '../tokens/ds_spacing.dart';

class DsEmptyState extends StatelessWidget {
  const DsEmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: DsSpacing.md),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (action != null) ...[const SizedBox(height: DsSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
