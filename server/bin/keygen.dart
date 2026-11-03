// Tạo cặp khoá Ed25519 để ký manifest OTA.
//
//   dart run bin/keygen.dart           # tạo keys/ota_signing.key (không ghi đè)
//   dart run bin/keygen.dart --force   # tạo lại (Shell cũ sẽ từ chối manifest mới!)
//
// - Private key: server/keys/ota_signing.key (base64 seed 32 byte). KHÔNG commit,
//   production nên để trong KMS/secret của CI.
// - Public key: in ra màn hình, dán vào `kOtaPublicKey` trong shell_app/lib/config.dart.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:ota_server/signing.dart';

Future<void> main(List<String> args) async {
  final file = File(signingKeyPath);
  if (file.existsSync() && !args.contains('--force')) {
    stderr.writeln('Đã có ${file.path}. Dùng --force nếu thật sự muốn tạo lại.');
    stdout.writeln('Public key hiện tại: ${await publicKeyBase64(await loadSigningKey())}');
    exit(1);
  }

  final keyPair = await Ed25519().newKeyPair();
  final seed = await keyPair.extractPrivateKeyBytes();
  file
    ..createSync(recursive: true)
    ..writeAsStringSync(base64Encode(seed));

  stdout
    ..writeln('✔ Đã ghi ${file.path}')
    ..writeln('Public key (dán vào kOtaPublicKey của Shell):')
    ..writeln(await publicKeyBase64(keyPair));
}
