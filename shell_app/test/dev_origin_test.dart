import 'package:app_theme/app_theme.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:shell_app/config.dart';
import 'package:shell_app/pages/dev_origin.dart';
import 'package:shell_app/policy/shell_config.dart';

void main() {
  group('parseDevUrl', () {
    test('http và https có host thì hợp lệ', () {
      final http = parseDevUrl('http://localhost:7357');
      expect(http, isNotNull);
      expect(http!.scheme, 'http');
      expect(http.host, 'localhost');
      expect(http.port, 7357);

      final https = parseDevUrl('https://shop.example/app');
      expect(https, isNotNull);
      expect(https!.scheme, 'https');
      expect(https.host, 'shop.example');
      expect(
        parseDevUrl('  http://localhost:7357  ')?.origin,
        'http://localhost:7357',
      );
    });

    test('rỗng hoặc không phải http(s) có host thì không mở', () {
      expect(parseDevUrl(''), isNull);
      expect(parseDevUrl('   '), isNull);
      expect(parseDevUrl('ftp://x'), isNull);
      expect(parseDevUrl('localhost:7357'), isNull);
      expect(parseDevUrl('http://'), isNull);
      expect(parseDevUrl('http://localhost:'), isNull);
    });
  });

  test('URL hợp lệ được gắn mode và brand, giữ fragment', () {
    const theme = ThemeSpec(mode: ThemeMode.light, brand: DsBrand.sunset);
    final out = applyDevTheme(
      Uri.parse('http://localhost:7357/index.html?x=1#/product/p2'),
      theme,
    );
    expect(out.queryParameters['mode'], 'light');
    final kept = applyDevTheme(
      Uri.parse('http://localhost:7357/?mode=dark'),
      theme,
    );
    expect(kept.queryParameters['mode'], 'light');
    expect(out.queryParameters['brand'], 'sunset');
    expect(out.queryParameters['seed'], theme.toJson()['seed']);
    expect(out.queryParameters['x'], '1');
    expect(out.fragment, '/product/p2');
    expect(out.path, '/index.html');
    expect(out.origin, 'http://localhost:7357');
  });

  group('allowsDevNavigation', () {
    final loaded = Uri.parse('http://localhost:7357');

    test('cùng origin thì cho điều hướng', () {
      expect(allowsDevNavigation(loaded, 'http://localhost:7357/'), isTrue);
      expect(
        allowsDevNavigation(
          loaded,
          'http://localhost:7357/index.html#/product/p2',
        ),
        isTrue,
      );
      expect(
        devNavigationBlockMessage(loaded, 'http://localhost:7357/a'),
        isNull,
      );
    });

    test('lệch origin hoặc scheme lạ thì chặn', () {
      expect(allowsDevNavigation(loaded, 'http://evil.test/x'), isFalse);
      expect(
        devNavigationBlockMessage(loaded, 'http://evil.test/x'),
        'Đã chặn mini app mở trang ngoài: evil.test',
      );
      expect(allowsDevNavigation(loaded, 'http://localhost:7358/'), isFalse);
      expect(allowsDevNavigation(loaded, 'https://localhost:7357/'), isFalse);
      expect(allowsDevNavigation(loaded, 'intent://scan/#Intent;end'), isFalse);
      expect(
        devNavigationBlockMessage(loaded, 'intent://scan/#Intent;end'),
        contains('scan'),
      );
      expect(allowsDevNavigation(loaded, 'tel:0912345678'), isFalse);
      expect(
        devNavigationBlockMessage(loaded, 'tel:0912345678'),
        'Đã chặn mini app mở trang ngoài: tel:0912345678',
      );
    });
  });

  group('parseDevAppId', () {
    test('nhận id kiểu mini_shop', () {
      expect(parseDevAppId('mini_shop'), 'mini_shop');
      expect(parseDevAppId(' mini_game '), 'mini_game');
      expect(parseDevAppId('new_app2'), 'new_app2');
    });

    test('từ chối rỗng, hoa, và ký tự lạ', () {
      expect(parseDevAppId(''), isNull);
      expect(parseDevAppId('MiniShop'), isNull);
      expect(parseDevAppId('mini-shop'), isNull);
    });
  });

  test('id có trong config dùng policy đó, id mới được đủ quyền bridge', () {
    const shop = AppPolicy(
      enabled: false,
      permissions: {BridgePermissions.userInfo},
    );
    const config = ShellConfig(version: 1, apps: {'mini_shop': shop});
    expect(devPolicyFor(config, 'mini_shop'), shop);
    expect(devPolicyFor(config, 'mini_shop').enabled, isFalse);

    final fresh = devPolicyFor(config, 'new_app');
    expect(fresh.enabled, isTrue);
    expect(fresh.permissions, BridgePermissions.all);
  });

  test('app đang tắt thì có SnackBar, không load', () {
    expect(
      devLockMessage(
        'mini_game',
        const AppPolicy(enabled: false, permissions: BridgePermissions.all),
      ),
      'Mini app "mini_game" đang tạm khoá.',
    );
    expect(
      devLockMessage(
        'new_app',
        const AppPolicy(permissions: BridgePermissions.all),
      ),
      isNull,
    );
  });

  group('handshake init', () {
    const theme = ThemeSpec(mode: ThemeMode.dark, brand: DsBrand.forest);

    test('trả theme, appVersion dev, user chỉ khi có userInfo', () {
      final withUser = devInitResult(theme: theme, includeUser: true);
      expect(withUser['theme'], theme.toJson());
      expect(withUser['appVersion'], 'dev');
      expect(withUser['shellVersion'], kShellVersion);
      expect(withUser['user'], kDemoUser.toJson());

      final withoutUser = devInitResult(theme: theme, includeUser: false);
      expect(withoutUser.containsKey('user'), isFalse);
      expect(withoutUser['appVersion'], 'dev');
    });

    test('method thiếu quyền thì host từ chối, không gọi handler', () async {
      final sent = <String>[];
      var paid = false;
      const policy = AppPolicy(permissions: {BridgePermissions.userInfo});
      final host = ShellBridgeHost(
        runJavaScript: (script) async => sent.add(script),
        hasPermission: policy.can,
        handlers: {
          BridgeMethods.init: (_) async => devInitResult(
            theme: theme,
            includeUser: policy.can(BridgePermissions.userInfo),
          ),
          BridgeMethods.requestPayment: (_) async {
            paid = true;
            return const {'status': 'success'};
          },
        },
      );
      await host.handleIncoming(
        const BridgeRequest(id: '1', method: BridgeMethods.init).encode(),
      );
      await host.handleIncoming(
        const BridgeRequest(
          id: '2',
          method: BridgeMethods.requestPayment,
        ).encode(),
      );
      expect(paid, isFalse);
      expect(sent.first, contains('appVersion'));
      expect(sent.first, contains('dev'));
      expect(sent.first, contains(kDemoUser.id));
      expect(sent.last, contains('Permission denied: payment'));
    });
  });
}
