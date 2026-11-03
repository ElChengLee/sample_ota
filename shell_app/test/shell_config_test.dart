import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:path/path.dart' as p;
import 'package:shell_app/config.dart';
import 'package:shell_app/mini_app/mini_app_repository.dart';
import 'package:shell_app/policy/shell_config.dart';

void main() {
  // Dùng đúng output của `dart run bin/publish_config.dart`.
  final publicDir = p.join('..', 'server', 'public');
  final body = File(p.join(publicDir, 'shell_config.json')).readAsBytesSync();
  final signature = File(p.join(publicDir, 'shell_config.json.sig')).readAsBytesSync();
  final publishedVersion = (jsonDecode(utf8.decode(body)) as Map)['version'] as int;

  late Directory tmp;
  late Map<String, Uint8List> files;
  late int hits;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('config_test');
    files = {'shell_config.json': body, 'shell_config.json.sig': signature};
    hits = 0;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ShellConfigStore store() => ShellConfigStore(
        repository: MiniAppRepository(
          serverUrl: 'http://localhost:8080',
          publicKey: kOtaPublicKey,
          rootDirectory: () async => tmp,
          client: MockClient((request) async {
            hits++;
            final file = files[request.url.path.substring(1)];
            return file == null ? http.Response('', 404) : http.Response.bytes(file, 200);
          }),
        ),
      );

  test('tải config đã ký: quyền + điều hướng chéo của cả app web lẫn native', () async {
    final s = store();
    expect(await s.refresh(), isTrue);
    final config = s.value;
    expect(config.version, publishedVersion);
    expect(config.policyOf('mini_shop').permissions, BridgePermissions.all);
    expect(config.policyOf('mini_shop').links.exported, {'/', '/product/*'});
    expect(config.policyOf('mini_game').permissions, {BridgePermissions.userInfo});
    expect(config.policyOf('mini_game').links.openableBy, {'mini_shop'});
    expect(config.policyOf('mini_native').links.canOpen, {'mini_shop', 'mini_game'});
    expect(config.policyOf('mini_native').enabled, isTrue);
    // App không có trong config: không quyền gì.
    expect(config.policyOf('la_hoac'), AppPolicy.unlisted);
  });

  test('chưa tải được gì thì mọi app đều không có quyền', () {
    expect(store().value.policyOf('mini_shop'), AppPolicy.unlisted);
  });

  test('config bị sửa (vd tự cấp quyền payment) thì bị từ chối, giữ bản cũ', () async {
    final source = utf8.decode(body);
    final game = RegExp(r'"mini_game"[\s\S]*?"userInfo"').firstMatch(source)!;
    files['shell_config.json'] = utf8.encode(source.replaceRange(game.end, game.end, ', "payment"'));
    final s = store();
    expect(await s.refresh(), isFalse);
    expect(s.value, same(ShellConfig.empty));
  });

  test('lưu lại trên máy: lần mở sau offline vẫn có quyền', () async {
    await store().refresh();
    files.clear(); // server không truy cập được
    final offline = store();
    await offline.ready;
    expect(offline.value.version, publishedVersion);
    expect(offline.value.policyOf('mini_shop').can(BridgePermissions.payment), isTrue);
  });

  test('không nhận config cũ hơn bản đang giữ (chống phát lại config đã ký cũ)', () async {
    // Giả lập máy đã có config mới hơn bản server đang trả.
    final newer = ShellConfig(version: publishedVersion + 5, apps: {'mini_shop': const AppPolicy()});
    File(p.join(tmp.path, ShellConfigStore.fileName)).writeAsStringSync(jsonEncode(newer.toJson()));
    final s = store();
    await s.load();
    expect(await s.refresh(), isFalse);
    expect(s.value.version, publishedVersion + 5);
    expect(s.value.policyOf('mini_shop').permissions, isEmpty);
  });

  test('refresh gọi dồn dập chỉ tải một lần', () async {
    final s = store();
    await Future.wait([s.refresh(), s.refresh(), s.refresh()]);
    expect(hits, 2); // shell_config.json + .sig
  });
}
