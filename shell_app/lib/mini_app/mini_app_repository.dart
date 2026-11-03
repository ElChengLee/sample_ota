import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_web_server.dart';
import 'mini_app_models.dart';

/// Quản lý vòng đời OTA của mini app: đọc manifest (đã ký), tải bundle + runtime,
/// verify, giải nén, cấp cổng, ghi registry.
///
/// Cấu trúc trên máy:
/// ```
/// <app support>/mini_apps/
///   registry.json                 { "<id>": { info..., "directory": "...", "port": 41xxx } }
///   mini_shop/1.4.0/index.html …  bundle (không có canvaskit/)
///   _runtimes/<engineRev>/canvaskit/…   CanvasKit dùng chung
/// ```
class MiniAppRepository {
  MiniAppRepository({
    required String serverUrl,
    required this.publicKey,
    http.Client? client,
    this._rootDirectory,
  })  : serverUrl = Uri.parse(serverUrl.endsWith('/') ? serverUrl : '$serverUrl/'),
        _client = client ?? http.Client();

  final Uri serverUrl;

  /// Public key Ed25519 (base64) dùng để verify `manifest.json.sig`.
  final String publicKey;
  final http.Client _client;

  /// Thư mục gốc chứa mini app; mặc định `<app support>/mini_apps` (test truyền thư mục tạm).
  final Future<Directory> Function()? _rootDirectory;

  /// Các thao tác ghi (registry, thư mục app/runtime) chạy tuần tự, tránh hai
  /// lần cài song song ghi đè registry của nhau hoặc dọn mất runtime của nhau.
  Future<void> _lockTail = Future.value();

  /// Runtime đang tải (dùng chung giữa các lần cài song song) và đang được dùng
  /// bởi một lần cài chưa ghi registry, để bước dọn runtime không xoá nhầm.
  final _runtimeJobs = <String, Future<void>>{};
  final _pinnedRuntimes = <String, int>{};

  static const _runtimesDirName = '_runtimes';

  /// Thư mục gốc dữ liệu OTA trên máy (registry, bundle, config đã lưu).
  Future<Directory> get rootDirectory => _rootDir;

  Future<Directory> get _rootDir async {
    final dir = await _rootDirectory?.call() ??
        Directory(p.join((await getApplicationSupportDirectory()).path, 'mini_apps'));
    return dir..createSync(recursive: true);
  }

  Future<File> get _registryFile async => File(p.join((await _rootDir).path, 'registry.json'));

  String _runtimeDir(String root, String engineRevision) => p.join(root, _runtimesDirName, engineRevision);

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _lockTail.then((_) => action());
    _lockTail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  // ───────────────────────────── Manifest ─────────────────────────────

  /// Tải `manifest.json` + `manifest.json.sig`, verify Ed25519 trên đúng các byte
  /// đã tải rồi mới parse. Manifest chứa sha256 của từng bundle/runtime nên toàn
  /// bộ chuỗi tải về đều được bảo vệ bởi chữ ký này.
  Future<List<MiniAppInfo>> fetchManifest() async {
    final json = await fetchSignedJson('manifest.json');
    final runtimes = (json['runtimes'] as Map? ?? const {}).cast<String, Object?>();
    return [
      for (final app in (json['apps'] as List).cast<Map>()) MiniAppInfo.fromJson(app.cast(), runtimes: runtimes),
    ];
  }

  /// Tải file JSON [name] + `[name].sig` từ server, verify Ed25519 trên đúng
  /// các byte đã tải rồi mới parse. Dùng cho manifest và config tổng của Shell.
  Future<Map<String, Object?>> fetchSignedJson(String name) async {
    _checkTransport(serverUrl);
    final body = await _get(serverUrl.resolve(name));
    final signature = await _get(serverUrl.resolve('$name.sig'));
    if (!await _verifySignature(body, utf8.decode(signature).trim())) {
      throw MiniAppInstallException('Chữ ký $name không hợp lệ: file bị sửa đổi hoặc ký bằng khoá khác');
    }
    return (jsonDecode(utf8.decode(body)) as Map).cast<String, Object?>();
  }

  Future<bool> _verifySignature(Uint8List message, String signatureBase64) async {
    try {
      return await crypto.Ed25519().verify(
        message,
        signature: crypto.Signature(
          base64Decode(signatureBase64),
          publicKey: crypto.SimplePublicKey(base64Decode(publicKey), type: crypto.KeyPairType.ed25519),
        ),
      );
    } on FormatException {
      return false;
    }
  }

  /// Release: chỉ HTTPS, trừ loopback (dev qua `adb reverse`). Debug cho phép
  /// HTTP để thử với IP LAN; tính toàn vẹn vẫn được chữ ký manifest đảm bảo.
  static void _checkTransport(Uri url) {
    final loopback = url.host == 'localhost' || url.host == '127.0.0.1' || url.host == '10.0.2.2';
    if (url.isScheme('https') || (url.isScheme('http') && (loopback || !kReleaseMode))) return;
    throw MiniAppInstallException('OTA server phải dùng HTTPS: $url');
  }

  Future<Uint8List> _get(Uri url) async {
    final response = await _client.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: url);
    return response.bodyBytes;
  }

  // ───────────────────────────── Registry ─────────────────────────────

  Future<Map<String, InstalledMiniApp>> installedApps() async => _readRegistry();

  /// Registry giữ trong bộ nhớ: mỗi lần mở mini app có vài chỗ hỏi (guard,
  /// deep link, trang), không cần đọc + parse file mỗi lần. Chỉ repository này
  /// ghi registry, và ghi qua [_writeRegistry] nên bản nhớ luôn khớp file.
  Map<String, InstalledMiniApp>? _registryCache;

  /// Trả bản sao: nơi gọi (vd [install]) sửa map rồi mới ghi.
  Future<Map<String, InstalledMiniApp>> _readRegistry() async => {...(_registryCache ??= await _loadRegistry())};

  /// Bỏ qua entry hỏng, entry từ định dạng cũ (chưa có runtime/port) hoặc thư mục
  /// đã mất: người dùng chỉ cần tải lại.
  Future<Map<String, InstalledMiniApp>> _loadRegistry() async {
    final file = await _registryFile;
    if (!file.existsSync()) return {};
    final root = (await _rootDir).path;
    final Map<String, Object?> json;
    try {
      json = (jsonDecode(await file.readAsString()) as Map).cast();
    } on FormatException catch (e) {
      debugPrint('[Repo] registry hỏng, bỏ qua: $e');
      return {};
    }
    final apps = <String, InstalledMiniApp>{};
    for (final MapEntry(:key, :value) in json.entries) {
      try {
        final entry = (value as Map).cast<String, Object?>();
        final info = MiniAppInfo.fromJson(entry);
        final app = InstalledMiniApp(
          info: info,
          directory: entry['directory'] as String,
          runtimeDirectory: _runtimeDir(root, info.runtime.engineRevision),
          port: (entry['port'] as num).toInt(),
        );
        if (Directory(app.directory).existsSync() && Directory(app.runtimeDirectory).existsSync()) {
          apps[key] = app;
        }
      } on Object catch (e) {
        debugPrint('[Repo] bỏ entry registry "$key": $e');
      }
    }
    return apps;
  }

  /// Ghi ra file tạm rồi rename: app bị kill giữa chừng cũng không để lại registry dở dang.
  Future<void> _writeRegistry(Map<String, InstalledMiniApp> apps) async {
    final json = {
      for (final MapEntry(:key, :value) in apps.entries)
        key: {...value.info.toJson(), 'directory': value.directory, 'port': value.port},
    };
    final file = await _registryFile;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(file.path);
    _registryCache = {...apps};
  }

  // ───────────────────────────── Install ─────────────────────────────

  /// Tải runtime (nếu chưa có) + bundle -> verify sha256 -> giải nén vào thư mục
  /// tạm -> rename -> cấp cổng -> ghi registry -> dọn version cũ và runtime thừa.
  Future<InstalledMiniApp> install(MiniAppInfo info, {void Function(double progress)? onProgress}) async {
    final root = (await _rootDir).path;
    final runtime = info.runtime;
    final revision = runtime.engineRevision;
    _pinnedRuntimes.update(revision, (n) => n + 1, ifAbsent: () => 1);
    try {
      final needRuntime = !Directory(_runtimeDir(root, revision)).existsSync();
      final total = info.size + (needRuntime ? runtime.size : 0);
      var done = 0;
      void report(int received) {
        if (total > 0) onProgress?.call(((done + received) / total).clamp(0, 1));
      }

      if (needRuntime) {
        await _ensureRuntime(runtime, root, report);
        done = runtime.size;
      }

      final bytes = await _download(serverUrl.resolve(info.bundleUrl), report);
      _verifyChecksum(bytes, info.sha256, '${info.id} ${info.version}');

      return await _synchronized(() async {
        final appDir = Directory(p.join(root, info.id))..createSync(recursive: true);
        final target = Directory(p.join(appDir.path, info.version));
        final staging = _extractToStaging(bytes, appDir.path);
        if (!File(p.join(staging.path, 'index.html')).existsSync()) {
          staging.deleteSync(recursive: true);
          throw MiniAppInstallException('Bundle ${info.id} thiếu index.html');
        }
        if (target.existsSync()) target.deleteSync(recursive: true);
        staging.renameSync(target.path);

        final apps = await _readRegistry();
        final installed = InstalledMiniApp(
          info: info,
          directory: target.path,
          runtimeDirectory: _runtimeDir(root, revision),
          // Giữ cổng cũ khi cập nhật để origin (và localStorage) không đổi.
          port: apps[info.id]?.port ?? _allocatePort(info.id, {for (final a in apps.values) a.port}),
        );
        apps[info.id] = installed;
        await _writeRegistry(apps);

        for (final old in appDir.listSync().whereType<Directory>()) {
          if (old.path != target.path) old.deleteSync(recursive: true);
        }
        await _collectRuntimes(root, apps);
        return installed;
      });
    } finally {
      final left = _pinnedRuntimes.update(revision, (n) => n - 1);
      if (left <= 0) _pinnedRuntimes.remove(revision);
    }
  }

  Future<void> uninstall(String id) => _synchronized(() async {
        final apps = await _readRegistry();
        final removed = apps.remove(id);
        await _writeRegistry(apps);
        if (removed != null) {
          final dir = Directory(p.dirname(removed.directory));
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
        await _collectRuntimes((await _rootDir).path, apps);
      });

  /// Nhiều lần cài cần cùng runtime thì chỉ tải một lần.
  Future<void> _ensureRuntime(MiniAppRuntime runtime, String root, void Function(int received) onReceived) {
    final revision = runtime.engineRevision;
    return _runtimeJobs[revision] ??= () async {
      try {
        final bytes = await _download(serverUrl.resolve(runtime.url), onReceived);
        _verifyChecksum(bytes, runtime.sha256, 'runtime $revision');
        await _synchronized(() async {
          final target = Directory(_runtimeDir(root, revision));
          if (target.existsSync()) return;
          final parent = Directory(p.dirname(target.path))..createSync(recursive: true);
          final staging = _extractToStaging(bytes, parent.path);
          if (!File(p.join(staging.path, 'canvaskit', 'canvaskit.js')).existsSync()) {
            staging.deleteSync(recursive: true);
            throw MiniAppInstallException('Runtime $revision thiếu canvaskit.js');
          }
          staging.renameSync(target.path);
        });
      } finally {
        _runtimeJobs.remove(revision);
      }
    }();
  }

  /// Xoá runtime không còn app nào dùng (và không có lần cài nào đang cần).
  Future<void> _collectRuntimes(String root, Map<String, InstalledMiniApp> apps) async {
    final dir = Directory(p.join(root, _runtimesDirName));
    if (!dir.existsSync()) return;
    final used = {for (final a in apps.values) a.info.runtime.engineRevision, ..._pinnedRuntimes.keys};
    for (final runtime in dir.listSync().whereType<Directory>()) {
      final name = p.basename(runtime.path);
      if (name.startsWith('.') || !used.contains(name)) runtime.deleteSync(recursive: true);
    }
  }

  /// Cổng đầu tiên còn trống tính từ vị trí hash của [appId].
  int _allocatePort(String appId, Set<int> used) {
    final preferred = LocalWebServer.preferredPort(appId);
    for (var i = 0; i < LocalWebServer.portRange; i++) {
      final port = LocalWebServer.portBase + (preferred - LocalWebServer.portBase + i) % LocalWebServer.portRange;
      if (!used.contains(port)) return port;
    }
    throw const MiniAppInstallException('Hết cổng local cho mini app');
  }

  void _verifyChecksum(Uint8List bytes, String expected, String label) {
    if (sha256.convert(bytes).toString() != expected) {
      throw MiniAppInstallException('Checksum không khớp cho $label (file hỏng hoặc bị sửa đổi)');
    }
  }

  Future<Uint8List> _download(Uri url, void Function(int received) onReceived) async {
    _checkTransport(url);
    final response = await _client.send(http.Request('GET', url));
    if (response.statusCode != 200) {
      throw MiniAppInstallException('Tải ${p.basename(url.path)} thất bại: HTTP ${response.statusCode}');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      onReceived(builder.length);
    }
    return builder.takeBytes();
  }

  /// Giải nén vào thư mục tạm có tên riêng trong [parentDir] (bắt đầu bằng '.').
  Directory _extractToStaging(Uint8List bytes, String parentDir) {
    final staging = Directory(p.join(parentDir, '.staging-${DateTime.now().microsecondsSinceEpoch}'));
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final outPath = p.normalize(p.join(staging.path, entry.name));
        // Chặn zip-slip: không cho file ghi ra ngoài thư mục đích.
        if (!p.isWithin(staging.path, outPath)) {
          throw MiniAppInstallException('Đường dẫn không hợp lệ trong bundle: ${entry.name}');
        }
        File(outPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(entry.content);
      }
      return staging;
    } on Object {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      rethrow;
    }
  }
}
