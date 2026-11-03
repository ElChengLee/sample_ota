// Phát hành config tổng của Shell: quyền bridge, quyền điều hướng chéo, bật/tắt
// từng mini app. Sửa xong chạy lại là các máy nhận config mới, không cần build
// lại Shell hay mini app.
//
//   dart run bin/publish_config.dart
//
// Input:  shell_config.json                 (file bạn sửa)
// Output: public/shell_config.json          bản chuẩn hoá + version tăng dần
//         public/shell_config.json.sig      chữ ký Ed25519 (base64)
import 'dart:convert';
import 'dart:io';

import 'package:ota_server/shell_config.dart';
import 'package:ota_server/signing.dart';
import 'package:path/path.dart' as p;

final _serverDir = p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..'));
final _sourceFile = File(p.join(_serverDir, 'shell_config.json'));
final _outputFile = File(p.join(_serverDir, 'public', 'shell_config.json'));
final _signatureFile = File(p.join(_serverDir, 'public', 'shell_config.json.sig'));

Future<void> main() async {
  final signingKey = await loadSigningKey();

  final Map<String, Object?> apps;
  final Object? source;
  try {
    source = jsonDecode(_sourceFile.readAsStringSync());
    apps = validateShellConfig(source);
  } on FormatException catch (e) {
    stderr.writeln('✘ ${p.relative(_sourceFile.path)}: ${e.message}');
    exit(1);
  }

  // Shell bỏ qua config có version nhỏ hơn bản nó đang giữ (chống phát lại
  // một config cũ, đã ký hợp lệ, để lấy lại quyền đã bị thu hồi). Nên mỗi lần
  // phát hành tự tăng version; file nguồn có thể đặt version lớn hơn nếu cần.
  final previous = _outputFile.existsSync()
      ? ((jsonDecode(_outputFile.readAsStringSync()) as Map)['version'] as num?)?.toInt() ?? 0
      : 0;
  final requested = ((source as Map)['version'] as num?)?.toInt() ?? 0;
  final version = requested > previous ? requested : previous + 1;

  final config = {
    'version': version,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'apps': apps,
  };
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(config));
  _outputFile.writeAsBytesSync(bytes);
  _signatureFile.writeAsStringSync(await sign(bytes, signingKey));

  stdout.writeln('✔ Đã phát hành ${p.relative(_outputFile.path)} version $version (+ chữ ký .sig)');
  for (final MapEntry(:key, :value) in apps.entries) {
    final app = value! as Map;
    final links = app['links'] as Map;
    stdout.writeln('  • $key${app['enabled'] == true ? '' : ' [TẠM KHOÁ]'}: '
        'quyền ${app['permissions']}, mở được ${links['canOpen']}, '
        'cho mở bởi ${links['openableBy']}, export ${links['exported']}');
  }
}
