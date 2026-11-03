import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../host.dart';
import '../mini_native_app.dart';
import 'detail_page.dart';

/// Màn gốc: liệt kê các điểm cần kiểm tra khi mini app native chạy trong Shell.
class CompatPage extends StatefulWidget {
  const CompatPage({super.key});

  @override
  State<CompatPage> createState() => _CompatPageState();
}

class _CompatPageState extends State<CompatPage> {
  static const _openCountKey = 'mini_native.openCount';

  /// Kết quả gọi plugin shared_preferences: số lần mở, hoặc lỗi.
  ({int? count, String? error})? _plugin;
  var _paying = false;
  var _adaptiveSwitch = true;

  @override
  void initState() {
    super.initState();
    _checkPlugin();
  }

  Future<void> _checkPlugin() async {
    try {
      final prefs = SharedPreferencesAsync();
      final count = (await prefs.getInt(_openCountKey) ?? 0) + 1;
      await prefs.setInt(_openCountKey, count);
      if (mounted) setState(() => _plugin = (count: count, error: null));
    } on MissingPluginException catch (e) {
      // Plugin chưa được đăng ký vào engine của host (vd host chưa pub get / build lại).
      if (mounted) setState(() => _plugin = (count: null, error: 'MissingPluginException: ${e.message}'));
    } on Object catch (e) {
      if (mounted) setState(() => _plugin = (count: null, error: '$e'));
    }
  }

  Future<void> _pay(MiniNativeHost host) async {
    setState(() => _paying = true);
    try {
      final ok = await host.requestPayment(amount: 49000, description: 'Mini Native: gói kiểm thử');
      host.showToast(ok ? 'Thanh toán thành công' : 'Đã huỷ thanh toán');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = MiniNativeScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primaryHex = (scheme.primary.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Đóng mini app', icon: const Icon(Icons.close), onPressed: host.close),
        title: const Text('Mini Native'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _CheckCard(
            title: 'Host',
            ok: host.embedded,
            okLabel: 'Trong Shell',
            failLabel: 'Standalone',
            failColor: DsColors.info,
            lines: [
              host.name,
              'User: ${host.user == null ? '(không có)' : '${host.user!.name} (${host.user!.id})'}',
            ],
          ),
          _CheckCard(
            title: 'Theme từ host',
            ok: true,
            okLabel: theme.brightness.name,
            lines: [
              'Primary: #$primaryHex',
              'Font: ${theme.textTheme.bodyMedium?.fontFamily ?? '(mặc định)'}',
              'Đổi theme ở Shell rồi quay lại: màu phải đổi theo, không cần khởi động lại.',
            ],
            child: Row(
              children: [
                for (final color in [scheme.primary, scheme.secondary, scheme.tertiary, scheme.surfaceContainerHighest])
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: DsSpacing.sm),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(DsRadius.sm)),
                  ),
                const Spacer(),
                // Material trên Android, Cupertino trên iOS.
                Switch.adaptive(value: _adaptiveSwitch, onChanged: (v) => setState(() => _adaptiveSwitch = v)),
              ],
            ),
          ),
          _CheckCard(
            title: 'Nền tảng',
            ok: true,
            okLabel: defaultTargetPlatform.name,
            lines: [
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
              'Dart ${Platform.version.split(' ').first}',
              'Chế độ: ${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'}',
            ],
          ),
          _CheckCard(
            title: 'Plugin native (shared_preferences)',
            ok: _plugin?.count != null,
            pending: _plugin == null,
            okLabel: 'Hoạt động',
            failLabel: 'Lỗi',
            lines: [
              if (_plugin == null) 'Đang gọi plugin…',
              if (_plugin?.count case final count?) 'Số lần mở mini app: $count (lưu qua plugin)',
              ?_plugin?.error,
            ],
          ),
          _CheckCard(
            title: 'Điều hướng bên trong',
            ok: true,
            okLabel: 'Navigator riêng',
            lines: const [
              'Mở màn chi tiết rồi bấm Back: phải về màn này, không đóng mini app.',
              'Ở màn này bấm Back: đóng mini app, về Home của Shell.',
            ],
            child: DsButton(
              label: 'Mở màn chi tiết',
              icon: Icons.arrow_forward,
              variant: DsButtonVariant.secondary,
              onPressed: () => Navigator.of(context).push(DetailPage.route(depth: 1)),
            ),
          ),
          _CheckCard(
            title: 'API của host',
            ok: true,
            okLabel: 'Gọi Dart trực tiếp',
            lines: const ['Không qua JS bridge, không serialize JSON.'],
            child: Wrap(
              spacing: DsSpacing.sm,
              runSpacing: DsSpacing.sm,
              children: [
                DsButton(
                  label: 'Toast',
                  icon: Icons.chat_bubble_outline,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => host.showToast('Xin chào từ Mini Native'),
                ),
                DsButton(
                  label: 'Thanh toán 49.000đ',
                  icon: Icons.payment,
                  loading: _paying,
                  onPressed: () => _pay(host),
                ),
                DsButton(
                  label: 'Deep link: Bánh mì',
                  icon: Icons.link,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => host.openDeepLink(Uri.parse('superapp://open/mini-app/mini_shop?path=/product/p2')),
                ),
                // mini_native khai báo được mở mini_game, nhưng mini_game chỉ
                // cho mini_shop mở (openableBy): Shell chặn.
                DsButton(
                  label: 'Mini Game (bị chặn)',
                  icon: Icons.block,
                  variant: DsButtonVariant.secondary,
                  onPressed: () async {
                    final opened = await host.openDeepLink(Uri.parse('superapp://open/mini-app/mini_game'));
                    debugPrint('[MiniNative] mở mini_game: $opened');
                  },
                ),
                DsButton(
                  label: 'Đóng',
                  icon: Icons.close,
                  variant: DsButtonVariant.ghost,
                  onPressed: host.close,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.title,
    required this.ok,
    required this.okLabel,
    required this.lines,
    this.failLabel = 'Lỗi',
    this.failColor = DsColors.danger,
    this.pending = false,
    this.child,
  });

  final String title;
  final bool ok;
  final bool pending;
  final String okLabel;
  final String failLabel;
  final Color failColor;
  final List<String> lines;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: DsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                DsBadge(
                  label: pending ? '…' : (ok ? okLabel : failLabel),
                  color: pending ? DsColors.info : (ok ? DsColors.success : failColor),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.sm),
            for (final line in lines) Text(line, style: theme.textTheme.bodyMedium),
            if (child != null) ...[const SizedBox(height: DsSpacing.md), child!],
          ],
        ),
      ),
    );
  }
}
