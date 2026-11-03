import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';
import 'package:path/path.dart' as p;
import 'package:shell_app/config.dart';
import 'package:shell_app/mini_app/local_web_server.dart';
import 'package:shell_app/mini_app/mini_app_models.dart';
import 'package:shell_app/mini_app/mini_app_repository.dart';

/// Server giả: trả file theo path, đếm số lần mỗi path được tải.
class _FakeServer {
  final files = <String, Uint8List>{};
  final hits = <String, int>{};

  late final client = MockClient.streaming((request, _) async {
    final path = request.url.path.substring(1);
    hits.update(path, (n) => n + 1, ifAbsent: () => 1);
    final body = files[path];
    if (body == null) return http.StreamedResponse(const Stream.empty(), 404);
    // Trả từng phần để có progress.
    return http.StreamedResponse(Stream.fromIterable([body.sublist(0, body.length ~/ 2), body.sublist(body.length ~/ 2)]), 200,
        contentLength: body.length);
  });
}

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(content))));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

void main() {
  late Directory tmp;
  late _FakeServer server;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ota_test');
    server = _FakeServer();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  MiniAppRepository repo() => MiniAppRepository(
        serverUrl: 'http://localhost:8080',
        publicKey: kOtaPublicKey,
        client: server.client,
        rootDirectory: () async => tmp,
      );

  group('manifest ký Ed25519', () {
    // Dùng đúng output của `dart run bin/build.dart`.
    final publicDir = p.join('..', 'server', 'public');
    final manifest = File(p.join(publicDir, 'manifest.json')).readAsBytesSync();
    final signature = File(p.join(publicDir, 'manifest.json.sig')).readAsBytesSync();

    test('chấp nhận manifest đúng chữ ký, đọc được runtime', () async {
      server.files
        ..['manifest.json'] = manifest
        ..['manifest.json.sig'] = signature;
      final apps = await repo().fetchManifest();
      final shop = apps.firstWhere((a) => a.id == 'mini_shop');
      expect(shop.runtime.url, startsWith('runtimes/canvaskit-'));
      expect(apps.map((a) => a.id), containsAll(['mini_shop', 'mini_game']));
    });

    test('từ chối manifest bị sửa dù chỉ 1 byte (vd đổi sha256 bundle)', () async {
      final source = utf8.decode(manifest);
      final sha = RegExp(r'"sha256": "').firstMatch(source)!;
      final tampered = utf8.encode(source.replaceRange(sha.end, sha.end + 1, source[sha.end] == '0' ? '1' : '0'));
      expect(tampered, isNot(manifest));
      server.files
        ..['manifest.json'] = Uint8List.fromList(tampered)
        ..['manifest.json.sig'] = signature;
      await expectLater(repo().fetchManifest(), throwsA(isA<MiniAppInstallException>()));
    });

    test('từ chối khi thiếu file chữ ký', () async {
      server.files['manifest.json'] = manifest;
      await expectLater(repo().fetchManifest(), throwsA(isA<HttpException>()));
    });
  });

  group('install', () {
    final runtimeZip = _zip({'canvaskit/canvaskit.js': '// ck', 'canvaskit/chromium/canvaskit.js': '// ck-chromium'});
    const rev = 'rev1';

    MiniAppInfo publish(String id, String version) {
      final zip = _zip({'index.html': '<html>$id $version</html>'});
      final url = 'bundles/$id-$version.zip';
      server.files[url] = zip;
      server.files['runtimes/canvaskit-$rev.zip'] = runtimeZip;
      return MiniAppInfo(
        id: id,
        name: id,
        description: '',
        icon: '',
        version: version,
        bundleUrl: url,
        sha256: sha256.convert(zip).toString(),
        size: zip.length,
        runtime: MiniAppRuntime(
          engineRevision: rev,
          url: 'runtimes/canvaskit-$rev.zip',
          sha256: sha256.convert(runtimeZip).toString(),
          size: runtimeZip.length,
        ),
      );
    }

    test('cài song song: registry đủ cả hai, runtime chỉ tải 1 lần, cổng khác nhau', () async {
      final r = repo();
      final progress = <double>[];
      final results = await Future.wait([
        r.install(publish('app_a', '1.0.0'), onProgress: progress.add),
        r.install(publish('app_b', '1.0.0')),
      ]);
      final installed = await r.installedApps();
      expect(installed.keys, unorderedEquals(['app_a', 'app_b']));
      expect(server.hits['runtimes/canvaskit-$rev.zip'], 1);
      expect(results[0].port, isNot(results[1].port));
      expect(progress.last, closeTo(1, 1e-9));
      expect(File(p.join(results[0].runtimeDirectory, 'canvaskit', 'canvaskit.js')).existsSync(), isTrue);
    });

    test('cập nhật giữ nguyên cổng và xoá version cũ', () async {
      final r = repo();
      final v1 = await r.install(publish('app_a', '1.0.0'));
      final v2 = await r.install(publish('app_a', '1.1.0'));
      expect(v2.port, v1.port);
      expect(Directory(v1.directory).existsSync(), isFalse);
      expect(server.hits['runtimes/canvaskit-$rev.zip'], 1, reason: 'runtime đã có, không tải lại');
    });

    test('cổng trùng hash vẫn được cấp cổng khác', () async {
      final r = repo();
      // Cài app_a trước để chiếm cổng ưu tiên của nó, rồi giả lập app khác có cùng cổng ưu tiên
      // bằng cách sửa registry: đổi cổng của app_a thành cổng ưu tiên của app_b.
      await r.install(publish('app_a', '1.0.0'));
      final registry = File(p.join(tmp.path, 'registry.json'));
      final json = jsonDecode(registry.readAsStringSync()) as Map<String, Object?>;
      (json['app_a'] as Map)['port'] = LocalWebServer.preferredPort('app_b');
      registry.writeAsStringSync(jsonEncode(json));

      // Repository mới: registry được giữ trong bộ nhớ, bản cũ không thấy file vừa sửa.
      final b = await repo().install(publish('app_b', '1.0.0'));
      expect(b.port, isNot(LocalWebServer.preferredPort('app_b')));
    });

    test('checksum sai thì không cài', () async {
      final info = publish('app_a', '1.0.0');
      server.files[info.bundleUrl] = _zip({'index.html': 'hacked'});
      await expectLater(repo().install(info), throwsA(isA<MiniAppInstallException>()));
      expect(await repo().installedApps(), isEmpty);
    });

    test('gỡ app cuối cùng thì dọn luôn runtime', () async {
      final r = repo();
      final a = await r.install(publish('app_a', '1.0.0'));
      final b = await r.install(publish('app_b', '1.0.0'));
      await r.uninstall('app_a');
      expect(Directory(a.runtimeDirectory).existsSync(), isTrue, reason: 'app_b vẫn dùng');
      await r.uninstall('app_b');
      expect(Directory(b.runtimeDirectory).existsSync(), isFalse);
    });

    test('LocalWebServer phục vụ /canvaskit/* từ runtime, còn lại từ thư mục app', () async {
      final app = await repo().install(publish('app_a', '1.0.0'));
      final web = await LocalWebServer.start(app.directory, runtimeDirectory: app.runtimeDirectory, port: app.port);
      addTearDown(web.close);
      final client = http.Client();
      addTearDown(client.close);
      expect((await client.get(web.origin.resolve('/index.html'))).body, contains('app_a 1.0.0'));
      expect((await client.get(web.origin.resolve('/canvaskit/chromium/canvaskit.js'))).body, '// ck-chromium');
      expect((await client.get(web.origin.resolve('/canvaskit/../registry.json'))).statusCode, 404);
    });
  });

  group('quyền bridge', () {
    test('ShellBridgeHost từ chối method thiếu quyền, không gọi handler', () async {
      final sent = <String>[];
      var paid = false;
      final host = ShellBridgeHost(
        runJavaScript: (script) async => sent.add(script),
        hasPermission: (perm) => perm == BridgePermissions.userInfo,
        handlers: {
          BridgeMethods.requestPayment: (_) async => paid = true,
          BridgeMethods.getUserInfo: (_) async => {'name': 'x'},
        },
      );
      await host.handleIncoming(const BridgeRequest(id: '1', method: BridgeMethods.requestPayment).encode());
      await host.handleIncoming(const BridgeRequest(id: '2', method: BridgeMethods.getUserInfo).encode());
      expect(paid, isFalse);
      expect(sent[0], contains('Permission denied: payment'));
      expect(sent[1], isNot(contains('Permission denied')));
    });
  });
}
