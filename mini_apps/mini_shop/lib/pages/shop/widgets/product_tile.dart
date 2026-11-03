import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../data/product.dart';
import '../../../utils/format.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.quantity,
    required this.onOpen,
    required this.onAdd,
  });

  final Product product;
  final int quantity;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DsCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(product.icon),
              ),
              const Spacer(),
              if (quantity > 0) DsBadge(label: 'x$quantity'),
            ],
          ),
          const Spacer(),
          Text(product.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: DsSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatVnd(product.price),
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              IconButton(
                tooltip: 'Thêm vào giỏ',
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
                icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
