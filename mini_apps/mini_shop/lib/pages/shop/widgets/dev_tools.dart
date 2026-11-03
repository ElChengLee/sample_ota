import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import '../../../config.dart';

/// Nút kiểm tra hành vi Shell trong tình huống biên. Chỉ hiện khi
/// [kShowDevTools].
class DevTools extends StatelessWidget {
  const DevTools({super.key, required this.shell});

  final ShellApi shell;

  /// Chiếm luồng JS: mọi message từ Shell (kể cả backPressed) bị treo theo.
  void _freeze(Duration duration) {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {}
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    // openDeepLink không ném lỗi: bị chặn thì Shell tự báo, mini app nhận false.
    Widget link(String label, IconData icon, Uri uri) => DsButton(
          label: label,
          icon: icon,
          variant: DsButtonVariant.secondary,
          onPressed: () => shell.openDeepLink(uri),
        );

    return DsCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Công cụ test', style: titleStyle),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              DsButton(label: 'close', icon: Icons.logout, variant: DsButtonVariant.secondary, onPressed: shell.close),
              DsButton(
                label: 'close sau 3s',
                icon: Icons.timer_outlined,
                variant: DsButtonVariant.secondary,
                onPressed: () => Future<void>.delayed(const Duration(seconds: 3), shell.close),
              ),
              DsButton(
                label: 'Treo JS 5s',
                icon: Icons.hourglass_bottom,
                variant: DsButtonVariant.secondary,
                onPressed: () => _freeze(const Duration(seconds: 5)),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text('Deep link qua Shell', style: titleStyle),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              // Link tới chính mini app: Shell gửi `navigate` ngược xuống.
              link('Kem vani', Icons.link, SuperAppLinks.miniApp(kAppId, path: '/product/p6')),
              link('Home Shell', Icons.home_outlined, SuperAppLinks.home()),
              link('Mini Game', Icons.sports_esports_outlined, SuperAppLinks.miniApp('mini_game')),
              link('Route sai', Icons.link_off, SuperAppLinks.miniApp(kAppId, path: '/khong-ton-tai')),
              // Config tổng: shop được mở mini_native, mini_native cho shop mở.
              link('Mini Native', Icons.phone_android, SuperAppLinks.nativeApp('mini_native')),
              // mini_game chỉ export "/": mở thẳng vào màn con bị Shell chặn.
              link('Game /settings (bị chặn)', Icons.block, SuperAppLinks.miniApp('mini_game', path: '/settings')),
            ],
          ),
        ],
      ),
    );
  }
}
