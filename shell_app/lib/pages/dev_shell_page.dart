import 'package:auto_route/auto_route.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../mini_app/mini_app_models.dart';
import '../mini_app/mini_app_repository.dart';
import '../mini_app/open_mini_app.dart';
import '../native_apps/native_mini_apps.dart';
import '../router/app_router.dart';
import '../shell_scope.dart';
import 'dev_mini_app_view.dart';
import 'dev_origin.dart';

/// `/dev`: vào tab DEBUG trước. Tab Live mở mini app như Home, nằm sau.
///
/// Cổng trong ô URL được nhớ ở application support. Phần còn lại chỉ sống trong trang này.
@RoutePage()
class DevShellPage extends StatefulWidget {
  const DevShellPage({super.key});

  @override
  State<DevShellPage> createState() => _DevShellPageState();
}

class _DevShellPageState extends State<DevShellPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTab);
  }

  void _onTab() {
    if (!mounted || _index == _tabs.index) return;
    setState(() => _index = _tabs.index);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.router.pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Host Debug Shell App'),
          actions: [
            // ✕ đóng thẳng /dev. router.pop bỏ qua PopScope, không hỏi backPressed.
            IconButton(
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
              onPressed: () => context.router.pop(),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'DEBUG'),
              Tab(text: 'LIVE'),
            ],
          ),
        ),
        body: IndexedStack(
          index: _index,
          sizing: StackFit.expand,
          children: [
            const _DevTab(),
            const _LiveTab(),
          ],
        ),
      ),
    );
  }
}

class _LiveTab extends StatefulWidget {
  const _LiveTab();

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  late final ShellScope _scope = ShellScope.read(context);
  List<MiniAppListing> _apps = const [];
  String? _manifestError;
  var _loading = true;
  final _downloads = <String, double>{};

  /// Chặn bấm mở liên tiếp push nhiều MiniAppPage. Giữ ở caller, không nhét vào hàm dùng chung.
  var _opening = false;

  MiniAppRepository get _repo => _scope.repository;

  @override
  void initState() {
    super.initState();
    _scope.config.addListener(_onConfigChanged);
    _refresh();
  }

  @override
  void dispose() {
    _scope.config.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() => setState(() {});

  bool _enabled(String appId) => _scope.config.value.policyOf(appId).enabled;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final configRefresh = _scope.config.refresh();
    final installed = await _repo.installedApps();
    List<MiniAppInfo> remote = const [];
    String? error;
    try {
      remote = await _repo.fetchManifest();
    } on Object catch (e) {
      debugPrint('[Dev] fetchManifest failed: $e');
      error =
          'Không kết nối được OTA server. Đang hiển thị các mini app đã cài.';
    }
    await configRefresh;
    if (!mounted) return;
    final remoteIds = remote.map((e) => e.id).toSet();
    setState(() {
      _loading = false;
      _manifestError = error;
      _apps = [
        for (final info in remote)
          MiniAppListing(remote: info, installed: installed[info.id]),
        for (final app in installed.values)
          if (!remoteIds.contains(app.info.id)) MiniAppListing(installed: app),
      ];
    });
  }

  Future<void> _open(MiniAppListing listing) async {
    if (_opening) return;
    _opening = true;
    try {
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

  String _label(MiniAppListing listing) {
    if (listing.needsDownload) return 'Tải & mở';
    if (listing.hasUpdate) return 'Cập nhật & mở';
    return 'Mở';
  }

  /// id, phiên bản và dung lượng — cùng các mốc Home dùng để quyết định nút.
  String _meta(MiniAppListing listing) {
    final info = listing.info;
    final sizeMb = '${(info.size / 1024 / 1024).toStringAsFixed(1)} MB';
    final version = switch (listing) {
      _ when listing.needsDownload => 'Chưa cài • $sizeMb',
      _ when listing.hasUpdate =>
        'v${listing.installed!.info.version} → v${listing.remote!.version}',
      _ => 'Đã cài v${listing.installed!.info.version}',
    };
    return '${info.id} • $version';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const DsSectionHeader(title: 'Mini apps'),
          if (_loading && _apps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(DsSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_manifestError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.md),
                child: Text(
                  _manifestError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_apps.isEmpty)
              const DsEmptyState(
                icon: Icons.cloud_off,
                message: 'Chưa có mini app nào',
              ),
            for (final app in _apps)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.md),
                child: _OpenRow(
                  title: app.info.name,
                  subtitle: _meta(app),
                  enabled: _enabled(app.info.id),
                  label: _label(app),
                  loading: _downloads[app.info.id] != null,
                  onOpen: () => _open(app),
                ),
              ),
          ],
          const DsSectionHeader(title: 'Mini app native'),
          for (final app in kNativeMiniApps)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.md),
              child: _OpenRow(
                title: app.name,
                subtitle: app.id,
                enabled: _enabled(app.id),
                label: 'Mở',
                onOpen: () =>
                    context.router.push(NativeMiniAppRoute(appId: app.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenRow extends StatelessWidget {
  const _OpenRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.label,
    required this.onOpen,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final String label;
  final VoidCallback onOpen;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DsCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          if (enabled)
            DsButton(
              label: label,
              icon: Icons.open_in_new,
              loading: loading,
              onPressed: loading ? null : onOpen,
            )
          else
            const DsBadge(label: 'Tạm khoá', color: DsColors.danger),
        ],
      ),
    );
  }
}

class _DevTab extends StatefulWidget {
  const _DevTab();

  @override
  State<_DevTab> createState() => _DevTabState();
}

class _DevTabState extends State<_DevTab> {
  final _appId = TextEditingController(text: kDevDefaultAppId);
  final _url = TextEditingController(text: kDevDefaultUrl)
    ..selection = TextSelection.collapsed(offset: kDevDefaultUrl.length);

  /// User đã sửa ô URL trước khi đọc xong cổng đã lưu thì không ghi đè.
  var _urlTouched = false;

  @override
  void initState() {
    super.initState();
    _restorePort();
  }

  Future<void> _restorePort() async {
    final port = readDevLastPort(await getApplicationSupportDirectory());
    if (!mounted || port == null || _urlTouched) return;
    final text = devUrlForPort(port);
    _url.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _rememberPort() {
    final port = devExplicitPort(_url.text);
    if (port == null) return;
    getApplicationSupportDirectory().then(writeDevLastPortThen(port));
  }

  void Function(Directory) writeDevLastPortThen(String port) =>
      (dir) => writeDevLastPort(dir, port);

  @override
  void dispose() {
    _appId.dispose();
    _url.dispose();
    super.dispose();
  }

  void _open(String? appId, Uri? url) {
    if (appId == null || url == null) return;
    final denied = devLockMessage(
      appId,
      devPolicyFor(ShellScope.of(context).config.value, appId),
    );
    if (denied != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(denied)));
      return;
    }
    context.router.pushWidget(DevMiniAppView(url: url, appId: appId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appId = parseDevAppId(_appId.text);
    final parsed = parseDevUrl(_url.text);
    final known =
        appId != null &&
        ShellScope.of(context).config.value.apps.containsKey(appId);
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _appId,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'App id',
              hintText: 'mini_shop',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _open(appId, parsed),
          ),
          if (appId == null) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              kDevAppIdError,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.xs),
              child: Text(
                known
                    ? 'Dùng quyền của $appId trong config.'
                    : '$appId chưa có trong config. Quyền bridge đầy đủ để phát triển.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: DsSpacing.md),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'http://localhost:7357',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _open(appId, parsed),
          ),
          if (parsed == null && _url.text.trim() != kDevDefaultUrl) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              kDevUrlError,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: DsSpacing.md),
          DsButton(
            label: 'Mở',
            icon: Icons.open_in_new,
            expanded: true,
            onPressed: appId == null || parsed == null
                ? null
                : () => _open(appId, parsed),
          ),
        ],
      ),
    );
  }
}
