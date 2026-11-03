import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import '../app.dart';
import '../config.dart';
import '../data/product.dart';
import '../utils/format.dart';

/// Màn con bên trong mini app, route `#/product/:productId`. Back của hệ thống
/// phải quay về danh sách, không được đóng cả mini app.
@RoutePage()
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, @PathParam('productId') required this.productId});

  final String productId;

  Future<void> _showPolicy(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chính sách đổi trả'),
          content: const Text('Đổi trả trong 30 phút nếu sai món. Dialog này để kiểm tra Back đóng dialog trước.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đã hiểu'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = productById(productId);
    if (product == null) {
      // productId lấy từ URL nên có thể sai (deep link cũ, gõ tay...).
      return Scaffold(
        appBar: AppBar(),
        body: DsEmptyState(icon: Icons.search_off, message: 'Không tìm thấy sản phẩm "$productId"'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        padding: const EdgeInsets.all(DsSpacing.lg),
        children: [
          DsCard(
            padding: const EdgeInsets.all(DsSpacing.xxl),
            child: Icon(product.icon, size: 96, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: DsSpacing.lg),
          Text(product.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: DsSpacing.xs),
          Text(formatVnd(product.price), style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: DsSpacing.md),
          Text(
            'Màn chi tiết là một route của auto_route (#/product/$productId). '
            'Nhấn Back của điện thoại: đóng dialog trước, rồi quay về danh sách, '
            'và chỉ đóng mini app khi đang ở màn gốc.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DsSpacing.md),
          SelectableText(
            'Deep link: ${SuperAppLinks.miniApp(kAppId, path: '/product/$productId')}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: DsSpacing.xl),
          DsButton(
            label: 'Thêm vào giỏ',
            icon: Icons.add_shopping_cart,
            expanded: true,
            onPressed: () {
              ShopScope.read(context).cart.add(product.id);
              context.router.maybePop();
            },
          ),
          const SizedBox(height: DsSpacing.sm),
          DsButton(
            label: 'Chính sách đổi trả',
            variant: DsButtonVariant.secondary,
            expanded: true,
            onPressed: () => _showPolicy(context),
          ),
        ],
      ),
    );
  }
}
