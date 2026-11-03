import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import '../../app.dart';
import '../../config.dart';
import '../../data/product.dart';
import '../../router/app_router.dart';
import 'widgets/checkout_bar.dart';
import 'widgets/dev_tools.dart';
import 'widgets/product_tile.dart';
import 'widgets/shop_header.dart';

/// Màn gốc `#/`: menu + giỏ hàng + thanh toán qua Shell.
@RoutePage()
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  var _paying = false;

  Future<void> _checkout() async {
    final ShopScope(:shell, :cart) = ShopScope.read(context);
    setState(() => _paying = true);
    try {
      // Thanh toán do Shell xử lý bằng UI native (bottom sheet của design system).
      final result = await shell.requestPayment(
        amount: cart.total,
        orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        description: 'Mini Shop - ${cart.count} sản phẩm',
      );
      if (!mounted) return;
      switch (result) {
        case PaymentSuccess(:final transactionId):
          cart.clear();
          await shell.showToast('Đặt hàng thành công ($transactionId)');
        case PaymentCancelled():
          _showMessage('Bạn đã hủy thanh toán');
        case PaymentFailed(permissionDenied: true):
          _showMessage('Mini Shop chưa được cấp quyền thanh toán');
        case PaymentFailed(:final reason):
          _showMessage('Thanh toán thất bại: $reason');
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final ShopScope(:shell, :cart) = ShopScope.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.lg, DsSpacing.lg, 0),
            sliver: SliverList.list(
              children: [
                ShopHeader(session: SessionScope.of(context), embedded: shell.isEmbedded),
                if (kShowDevTools) ...[
                  const SizedBox(height: DsSpacing.md),
                  DevTools(shell: shell),
                ],
                const DsSectionHeader(title: 'Menu hôm nay'),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            sliver: ListenableBuilder(
              listenable: cart,
              builder: (context, _) => SliverGrid.builder(
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 170,
                  crossAxisSpacing: DsSpacing.md,
                  mainAxisSpacing: DsSpacing.md,
                ),
                itemBuilder: (context, i) {
                  final product = products[i];
                  return ProductTile(
                    product: product,
                    quantity: cart.quantityOf(product.id),
                    onOpen: () => context.router.push(ProductDetailRoute(productId: product.id)),
                    onAdd: () => cart.add(product.id),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: cart,
        builder: (context, _) => cart.count == 0
            ? const SizedBox.shrink()
            : CheckoutBar(count: cart.count, total: cart.total, paying: _paying, onCheckout: _checkout),
      ),
    );
  }
}
