import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// UI thanh toán native của Shell, mở khi mini app gọi `requestPayment`.
/// Trả về `true` nếu người dùng xác nhận.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.appName, required this.amount, required this.description});

  final String appName;
  final int amount;
  final String description;

  static Future<bool> show(BuildContext context, {required String appName, required Map<String, Object?> params}) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentSheet(
        appName: appName,
        amount: (params['amount'] as num?)?.toInt() ?? 0,
        description: params['description'] as String? ?? '',
      ),
    );
    return confirmed ?? false;
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  var _processing = false;

  Future<void> _confirm() async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900)); // giả lập gọi cổng thanh toán
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: DsSpacing.sm),
                Text('Xác nhận thanh toán', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            Text('Yêu cầu từ mini app "${widget.appName}" — xử lý bởi Shell (native)',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: DsSpacing.lg),
            DsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: DsSpacing.xs),
                  Text(_formatVnd(widget.amount), style: theme.textTheme.headlineMedium),
                  const SizedBox(height: DsSpacing.sm),
                  const DsBadge(label: 'Ví Shell • số dư 1.250.000đ'),
                ],
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
            DsButton(label: 'Thanh toán', expanded: true, loading: _processing, onPressed: _confirm),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: 'Hủy',
              variant: DsButtonVariant.ghost,
              expanded: true,
              onPressed: _processing ? null : () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatVnd(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
}
