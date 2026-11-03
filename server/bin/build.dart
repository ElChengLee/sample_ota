// Build tất cả mini app trong ../mini_apps thành bundle OTA.
//
//   dart run bin/build.dart            # build tất cả
//   dart run bin/build.dart mini_shop  # build 1 app
//   dart run bin/build.dart --no-dev-tools   # tắt "Công cụ test" trong mini app (bản phát hành thật)
//
// Output:
//   public/bundles/<id>-<version>.zip          build/web, KHÔNG gồm canvaskit/
//   public/runtimes/canvaskit-<engineRev>.zip  CanvasKit dùng chung, mỗi engine revision một file
//   public/manifest.json                       danh sách app + runtime + sha256
//   public/manifest.json.sig                   chữ ký Ed25519 (base64) trên đúng byte của manifest.json
//
// Quyền bridge và quyền điều hướng chéo KHÔNG nằm ở đây: xem bin/publish_config.dart.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:ota_server/signing.dart';
import 'package:path/path.dart' as p;

final _serverDir = p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..'));
final _miniAppsDir = p.join(_serverDir, '..', 'mini_apps');
final _publicDir = p.join(_serverDir, 'public');
final _bundlesDir = p.join(_publicDir, 'bundles');
final _runtimesDir = p.join(_publicDir, 'runtimes');
final _manifestFile = File(p.join(_publicDir, 'manifest.json'));
final _signatureFile = File(p.join(_publicDir, 'manifest.json.sig'));

/// File CanvasKit mà bản build dart2js thực sự tải: bản đầy đủ (WKWebView/iOS) và
/// bản `chromium` (Android WebView). skwasm / wimp chỉ dành cho bản build --wasm,
/// webparagraph chỉ khi bật `preferWebParagraph`, `.symbols` chỉ để debug.
const _runtimeFiles = [
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
];

Future<void> main(List<String> args) async {
  final devTools = !args.contains('--no-dev-tools');
  final names = args.where((a) => !a.startsWith('--')).toList();
  final signingKey = await loadSigningKey();
  Directory(_bundlesDir).createSync(recursive: true);
  Directory(_runtimesDir).createSync(recursive: true);

  final appDirs = Directory(_miniAppsDir)
      .listSync()
      .whereType<Directory>()
      .where((d) => File(p.join(d.path, 'mini_app.json')).existsSync())
      .where((d) => names.isEmpty || names.contains(p.basename(d.path)))
      .toList();

  if (appDirs.isEmpty) {
    stderr.writeln('Không tìm thấy mini app nào (cần file mini_app.json).');
    exit(1);
  }

  // Giữ entry của các app không build lần này.
  final previous = _manifestFile.existsSync()
      ? (jsonDecode(_manifestFile.readAsStringSync()) as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final entries = <String, Map<String, Object?>>{
    for (final app in (previous['apps'] as List? ?? const []).cast<Map>())
      app['id'] as String: {...app.cast<String, Object?>()}
        // Manifest cũ còn quyền trong từng app; nay nằm ở shell_config.json.
        ..remove('permissions')
        ..remove('links'),
  };
  final runtimes = <String, Object?>{...(previous['runtimes'] as Map? ?? const {}).cast<String, Object?>()};

  for (final dir in appDirs) {
    final (entry, runtime) = await _buildApp(dir, devTools: devTools);
    entries[entry['id'] as String] = entry;
    runtimes[entry['engineRevision'] as String] = runtime;
  }

  // Chỉ giữ runtime còn được app nào đó tham chiếu.
  final usedRevisions = entries.values.map((e) => e['engineRevision']).toSet();
  runtimes.removeWhere((rev, _) => !usedRevisions.contains(rev));

  final manifest = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'runtimes': runtimes,
    'apps': entries.values.toList(),
  };
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
  _manifestFile.writeAsBytesSync(bytes);
  _signatureFile.writeAsStringSync(await sign(bytes, signingKey));
  stdout
    ..writeln('\n✔ Đã ghi ${p.relative(_manifestFile.path)} + chữ ký .sig')
    ..writeln('  public key: ${await publicKeyBase64(signingKey)}');
}

Future<(Map<String, Object?>, Map<String, Object?>)> _buildApp(Directory dir, {required bool devTools}) async {
  final meta = (jsonDecode(File(p.join(dir.path, 'mini_app.json')).readAsStringSync()) as Map).cast<String, Object?>();
  final id = meta['id'] as String;
  final version = _readVersion(File(p.join(dir.path, 'pubspec.yaml')));
  // Quyền và điều hướng chéo do Shell quản lý tập trung (shell_config.json),
  // để đổi được mà không phải build lại mini app.
  for (final key in const ['permissions', 'links']) {
    if (meta.containsKey(key)) {
      stderr.writeln('✘ $id: "$key" không còn khai báo trong mini_app.json, chuyển sang server/shell_config.json');
      exit(1);
    }
  }

  stdout.writeln('\n▶ Build $id v$version');
  // - base-href "/": Shell serve mỗi mini app ở root của một local server riêng.
  // - no-web-resources-cdn: CanvasKit lấy từ local (runtime dùng chung do Shell phục vụ), không từ CDN.
  final result = await Process.start(
    'flutter',
    [
      'build', 'web', '--release',
      '--base-href', '/',
      '--no-web-resources-cdn',
      '--dart-define=APP_VERSION=$version',
      // Demo: bật khối "Công cụ test" của mini app (kShowDevTools).
      '--dart-define=DEV_TOOLS=$devTools',
    ],
    workingDirectory: dir.path,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await result.exitCode != 0) {
    stderr.writeln('✘ Build $id thất bại');
    exit(1);
  }

  final webDir = Directory(p.join(dir.path, 'build', 'web'));
  final engineRevision = _readEngineRevision(webDir);
  final runtime = _ensureRuntime(webDir, engineRevision);

  final archive = Archive();
  for (final file in webDir.listSync(recursive: true).whereType<File>()) {
    // Tên trong zip luôn dùng '/' kể cả khi build trên Windows.
    final name = p.relative(file.path, from: webDir.path).replaceAll(r'\', '/');
    if (name.startsWith('canvaskit/')) continue; // nằm trong runtime dùng chung
    archive.addFile(ArchiveFile.bytes(name, file.readAsBytesSync()));
  }
  final bytes = ZipEncoder().encodeBytes(archive);
  final fileName = '$id-$version.zip';
  File(p.join(_bundlesDir, fileName)).writeAsBytesSync(bytes);

  final sha = sha256.convert(bytes).toString();
  stdout.writeln('✔ $fileName  ${_mb(bytes.length)}  sha256=${sha.substring(0, 12)}…  engine=${engineRevision.substring(0, 10)}');

  final entry = {
    ...meta,
    'version': version,
    'bundleUrl': 'bundles/$fileName',
    'sha256': sha,
    'size': bytes.length,
    'engineRevision': engineRevision,
  };
  return (entry, runtime);
}

/// Đóng gói CanvasKit một lần cho mỗi engine revision. Các app build cùng phiên
/// bản Flutter dùng chung file này, Shell chỉ tải một lần.
Map<String, Object?> _ensureRuntime(Directory webDir, String engineRevision) {
  final fileName = 'canvaskit-$engineRevision.zip';
  final file = File(p.join(_runtimesDir, fileName));
  if (!file.existsSync()) {
    final archive = Archive();
    for (final name in _runtimeFiles) {
      final source = File(p.join(webDir.path, name));
      if (!source.existsSync()) {
        stderr.writeln('✘ Thiếu $name trong build/web (cần --no-web-resources-cdn)');
        exit(1);
      }
      archive.addFile(ArchiveFile.bytes(name, source.readAsBytesSync()));
    }
    file.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    stdout.writeln('✔ runtime $fileName  ${_mb(file.lengthSync())}');
  }
  final bytes = file.readAsBytesSync();
  return {
    'url': 'runtimes/$fileName',
    'sha256': sha256.convert(bytes).toString(),
    'size': bytes.length,
  };
}

/// `flutter_bootstrap.js` chứa `"engineRevision":"<hash>"` trong buildConfig.
String _readEngineRevision(Directory webDir) {
  final bootstrap = File(p.join(webDir.path, 'flutter_bootstrap.js')).readAsStringSync();
  final match = RegExp(r'"engineRevision"\s*:\s*"([0-9a-f]+)"').firstMatch(bootstrap);
  if (match == null) throw StateError('Không đọc được engineRevision trong flutter_bootstrap.js');
  return match.group(1)!;
}

String _readVersion(File pubspec) {
  final match = RegExp(r'^version:\s*([^\s+#]+)', multiLine: true).firstMatch(pubspec.readAsStringSync());
  if (match == null) throw StateError('Thiếu version trong ${pubspec.path}');
  return match.group(1)!;
}

String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
