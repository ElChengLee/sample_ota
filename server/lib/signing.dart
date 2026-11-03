import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

/// Đường dẫn tính từ script đang chạy (bin/*.dart).
final signingKeyPath =
    p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..', 'keys', 'ota_signing.key'));

Future<SimpleKeyPair> loadSigningKey() async {
  final file = File(signingKeyPath);
  if (!file.existsSync()) {
    stderr.writeln('Thiếu khoá ký ${file.path}. Chạy: dart run bin/keygen.dart');
    exit(1);
  }
  return Ed25519().newKeyPairFromSeed(base64Decode(file.readAsStringSync().trim()));
}

Future<String> publicKeyBase64(SimpleKeyPair keyPair) async =>
    base64Encode((await keyPair.extractPublicKey()).bytes);

/// Chữ ký Ed25519 trên đúng các byte của manifest.json, mã hoá base64.
Future<String> sign(List<int> bytes, SimpleKeyPair keyPair) async =>
    base64Encode((await Ed25519().sign(bytes, keyPair: keyPair)).bytes);
