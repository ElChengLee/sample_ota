// Static server đóng vai CDN/OTA server cho Shell.
//
//   dart run bin/serve.dart [port]   (mặc định 8080)
//
// Shell gọi GET /manifest.json rồi tải GET /bundles/<id>-<version>.zip.
import 'dart:io';

import 'package:path/path.dart' as p;

final _publicDir = p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..', 'public'));

const _contentTypes = {
  '.json': 'application/json; charset=utf-8',
  '.zip': 'application/zip',
  '.sig': 'text/plain; charset=utf-8',
};

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  stdout.writeln('OTA server đang chạy, phục vụ $_publicDir');
  stdout.writeln('  • Android emulator : http://10.0.2.2:$port');
  stdout.writeln('  • iOS simulator    : http://localhost:$port');
  for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final addr in iface.addresses) {
      stdout.writeln('  • Thiết bị thật    : http://${addr.address}:$port  (${iface.name})');
    }
  }

  await for (final request in server) {
    final relative = p.normalize(Uri.decodeComponent(request.uri.path).replaceFirst(RegExp('^/+'), ''));
    final file = File(p.join(_publicDir, relative));
    final insidePublic = p.isWithin(_publicDir, file.path);

    if (!insidePublic || !file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      stdout.writeln('404 ${request.uri.path}');
      continue;
    }

    final length = file.lengthSync();
    request.response.headers
      ..contentType = ContentType.parse(_contentTypes[p.extension(file.path)] ?? 'application/octet-stream')
      ..contentLength = length
      ..set(HttpHeaders.cacheControlHeader, 'no-cache');
    await request.response.addStream(file.openRead());
    await request.response.close();
    stdout.writeln('200 ${request.uri.path} ($length bytes)');
  }
}
