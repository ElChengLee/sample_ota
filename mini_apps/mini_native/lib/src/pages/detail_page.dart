import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Màn con để kiểm tra Navigator riêng của mini app: push nhiều tầng, mở
/// dialog / bottom sheet, rồi Back phải pop đúng thứ tự.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.depth});

  final int depth;

  static Route<void> route({required int depth}) =>
      MaterialPageRoute(builder: (_) => DetailPage(depth: depth), settings: RouteSettings(name: '/detail/$depth'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Chi tiết #$depth')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: DsSpacing.md),
              Text('Tầng $depth trong Navigator của mini app', style: theme.textTheme.titleMedium),
              const SizedBox(height: DsSpacing.xl),
              DsButton(
                label: 'Mở tầng ${depth + 1}',
                icon: Icons.arrow_forward,
                expanded: true,
                onPressed: () => Navigator.of(context).push(route(depth: depth + 1)),
              ),
              const SizedBox(height: DsSpacing.sm),
              DsButton(
                label: 'Mở bottom sheet',
                icon: Icons.vertical_align_top,
                variant: DsButtonVariant.secondary,
                expanded: true,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(DsSpacing.xl),
                      child: Text('Bấm Back: sheet đóng, vẫn ở màn chi tiết.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
