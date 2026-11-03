import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import '../../../config.dart';
import '../../../data/key_value_store.dart';

class ShopHeader extends StatelessWidget {
  const ShopHeader({super.key, required this.session, required this.embedded});

  final MiniAppContext session;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = session.user;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon thay cho emoji 👋: emoji cần font Noto Color Emoji tải từ gstatic.
          Row(
            children: [
              Flexible(
                child: Text(user == null ? 'Xin chào' : 'Xin chào, ${user.name}', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(width: DsSpacing.xs),
              Icon(Icons.waving_hand_outlined, color: theme.colorScheme.primary),
            ],
          ),
          if (user == null)
            Text('Mini app chưa được cấp quyền xem thông tin người dùng.', style: theme.textTheme.labelSmall),
          const SizedBox(height: DsSpacing.xs),
          Text(
            'Màn hình này là Flutter Web, được Shell tải về và chạy trong WebView. '
            'Màu sắc & component lấy từ cùng package design_system/app_theme với Shell.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DsSpacing.md),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              DsBadge(label: 'build $kBuildVersion'),
              DsBadge(label: 'shell ${session.shellVersion}', color: DsColors.info),
              DsBadge(
                label: embedded ? 'embedded' : 'standalone',
                color: embedded ? DsColors.success : DsColors.warning,
              ),
            ],
          ),
          if (kShowDevTools) ...[
            const SizedBox(height: DsSpacing.sm),
            // Kiểm tra Shell chặn WebView điều hướng ra ngoài origin của mini app.
            DsButton(
              label: 'Thử mở link ngoài',
              icon: Icons.link,
              variant: DsButtonVariant.ghost,
              onPressed: () => navigateTopLevel('https://flutter.dev'),
            ),
          ],
        ],
      ),
    );
  }
}
