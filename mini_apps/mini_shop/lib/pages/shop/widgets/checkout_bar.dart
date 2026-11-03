import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../utils/format.dart';

class CheckoutBar extends StatelessWidget {
  const CheckoutBar({
    super.key,
    required this.count,
    required this.total,
    required this.paying,
    required this.onCheckout,
  });

  final int count;
  final int total;
  final bool paying;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count sản phẩm', style: theme.textTheme.bodyMedium),
                  Text(formatVnd(total), style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            DsButton(label: 'Thanh toán', icon: Icons.payments_outlined, loading: paying, onPressed: onCheckout),
          ],
        ),
      ),
    );
  }
}
