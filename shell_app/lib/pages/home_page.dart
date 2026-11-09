import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import '../config.dart';
import '../mini_app/mini_app_models.dart';
import '../mini_app/mini_app_repository.dart';
import '../mini_app/open_mini_app.dart';
import '../native_apps/native_mini_apps.dart';
import '../router/app_router.dart';
import '../shell_scope.dart';
import 'theme_settings.dart';

/// Shell mở thẳng một màn trong mini app bằng cùng định dạng link mà hệ điều
/// hành gửi vào (`superapp://open/...`), không gọi route của mini app trực tiếp.
final _sampleLinks = [
  ('Bánh mì thịt', SuperAppLinks.miniApp('mini_shop', path: '/product/p2')),
  ('Trà đào cam sả', SuperAppLinks.miniApp('mini_shop', path: '/product/p3')),
  ('Mini Game (chưa cài)', SuperAppLinks.miniApp('mini_game')),
  ('Mini Native', SuperAppLinks.nativeApp('mini_native')),
];

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MiniAppListing> _apps = const [];
  String? _manifestError;
  var _loading = true;

  /// id -> tiến độ tải (0..1) của app đang tải.
  final _downloads = <String, double>{};

  /// Chặn bấm "Mở" liên tiếp (tap đúp) push nhiều MiniAppPage.
  var _opening = false;

  late final ShellScope _scope = ShellScope.read(context);

  MiniAppRepository get _repo => _scope.repository;

  @override
  void initState() {
    super.initState();
    _scope.config.addListener(_onConfigChanged);
    _refresh();
    // Tạo sẵn WebView sau khi Home đã hiện, để lần mở mini app đầu tiên không
    // phải chờ nạp Chromium/WebKit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _scope.webViews.warmUp();
      });
    });
  }

  @override
  void dispose() {
    _scope.config.removeListener(_onConfigChanged);
    super.dispose();
  }

  /// Config tổng đổi (vd app bị tạm khoá / mở khoá): vẽ lại trạng thái các app.
  void _onConfigChanged() => setState(() {});

  bool _enabled(String appId) => _scope.config.value.policyOf(appId).enabled;

  /// Ghép manifest remote với registry local. Nếu server không truy cập được,
  /// vẫn liệt kê các app đã cài để mở offline.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    // Làm mới config tổng song song với manifest.
    final configRefresh = _scope.config.refresh();
    final installed = await _repo.installedApps();
    List<MiniAppInfo> remote = const [];
    String? error;
    try {
      remote = await _repo.fetchManifest();
    } on Object catch (e) {
      debugPrint('[Home] fetchManifest failed: $e');
      error = 'Không kết nối được OTA server. Đang hiển thị các mini app đã cài.';
    }
    await configRefresh;
    if (!mounted) return;
    final remoteIds = remote.map((e) => e.id).toSet();
    setState(() {
      _loading = false;
      _manifestError = error;
      _apps = [
        for (final info in remote) MiniAppListing(remote: info, installed: installed[info.id]),
        for (final app in installed.values)
          if (!remoteIds.contains(app.info.id)) MiniAppListing(installed: app),
      ];
    });
  }

  Future<void> _open(MiniAppListing listing) async {
    if (_opening) return;
    _opening = true;
    try {
      // Future hoàn tất khi mini app đóng -> _opening giữ true suốt thời gian đó.
      await installAndOpenMiniApp(
        context,
        listing: listing,
        repository: _repo,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloads[listing.info.id] = progress);
        },
        onFinished: () {
          if (!mounted) return;
          setState(() => _downloads.remove(listing.info.id));
        },
        refresh: _refresh,
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> _uninstall(MiniAppListing listing) async {
    await _repo.uninstall(listing.info.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super App'),
        actions: [
          TextButton(
            onPressed: () {
              if (context.router.current.name == DevShellRoute.name) return;
              context.router.push(const DevShellRoute());
            },
            child: const Text('DEBUG'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          // Cộng inset đáy: Android 15 edge-to-edge, thanh điều hướng đè lên nội dung.
          padding: EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.lg,
            DsSpacing.lg,
            DsSpacing.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            DsCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(kDemoUser.name.characters.first, style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: DsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kDemoUser.name, style: theme.textTheme.titleMedium),
                        Text('Shell v$kShellVersion • native Flutter', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DsSectionHeader(
              title: 'Mini apps',
              trailing: IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ),
            if (_loading && _apps.isEmpty)
              const Padding(padding: EdgeInsets.all(DsSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else ...[
              if (_manifestError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.md),
                  child: Text(
                    _manifestError!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              if (_apps.isEmpty)
                const DsEmptyState(icon: Icons.cloud_off, message: 'Chưa có mini app nào'),
              for (final app in _apps)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.md),
                  child: _MiniAppTile(
                    listing: app,
                    progress: _downloads[app.info.id],
                    enabled: _enabled(app.info.id),
                    onOpen: () => _open(app),
                    onUninstall: app.installed == null ? null : () => _uninstall(app),
                  ),
                ),
            ],
            const DsSectionHeader(title: 'Mini app native (biên dịch sẵn)'),
            for (final app in kNativeMiniApps)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.md),
                child: DsCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        foregroundColor: theme.colorScheme.onTertiaryContainer,
                        child: Icon(app.icon),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.name, style: theme.textTheme.titleMedium),
                            Text(app.description, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      if (_enabled(app.id))
                        DsButton(
                          label: 'Mở',
                          icon: Icons.open_in_new,
                          onPressed: () => context.router.push(NativeMiniAppRoute(appId: app.id)),
                        )
                      else
                        const DsBadge(label: 'Tạm khoá', color: DsColors.danger),
                    ],
                  ),
                ),
              ),
            const DsSectionHeader(title: 'Deep link vào mini app'),
            Wrap(
              spacing: DsSpacing.sm,
              runSpacing: DsSpacing.sm,
              children: [
                for (final (label, link) in _sampleLinks)
                  DsButton(
                    label: label,
                    icon: Icons.link,
                    variant: DsButtonVariant.secondary,
                    onPressed: () => _scope.deepLinks.open(link),
                  ),
              ],
            ),
            const DsSectionHeader(title: 'Giao diện (đồng bộ sang mini app)'),
            ThemeSettings(controller: _scope.themeController),
            const SizedBox(height: DsSpacing.md),
            Text('OTA server: $miniAppServerUrl', style: theme.textTheme.labelSmall),
            Text(
              _scope.config.value.version == 0
                  ? 'Config quyền: chưa tải được'
                  : 'Config quyền: v${_scope.config.value.version}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAppTile extends StatelessWidget {
  const _MiniAppTile({
    required this.listing,
    required this.progress,
    required this.enabled,
    required this.onOpen,
    this.onUninstall,
  });

  final MiniAppListing listing;
  final double? progress;

  /// `false`: đang tạm khoá trong config tổng, không cho mở.
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback? onUninstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = listing.info;
    final downloading = progress != null;
    final sizeMb = '${(info.size / 1024 / 1024).toStringAsFixed(1)} MB';

    final (String status, Color statusColor, String action) = switch (listing) {
      _ when listing.needsDownload => ('Chưa cài • $sizeMb', DsColors.warning, 'Tải & mở'),
      _ when listing.hasUpdate => (
          'v${listing.installed!.info.version} → v${listing.remote!.version}',
          DsColors.info,
          'Cập nhật & mở',
        ),
      _ => ('Đã cài v${listing.installed!.info.version}', DsColors.success, 'Mở'),
    };

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                child: Icon(info.iconData),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name, style: theme.textTheme.titleMedium),
                    Text(info.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (onUninstall != null && !downloading)
                IconButton(tooltip: 'Gỡ cài đặt', onPressed: onUninstall, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          if (downloading) ...[
            LinearProgressIndicator(value: progress),
            const SizedBox(height: DsSpacing.xs),
            Text('Đang tải bundle… ${(progress! * 100).toStringAsFixed(0)}%', style: theme.textTheme.labelSmall),
          ] else
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: enabled
                        ? DsBadge(label: status, color: statusColor)
                        : const DsBadge(label: 'Tạm khoá', color: DsColors.danger),
                  ),
                ),
                DsButton(label: action, icon: Icons.open_in_new, onPressed: enabled ? onOpen : null),
              ],
            ),
        ],
      ),
    );
  }
}
