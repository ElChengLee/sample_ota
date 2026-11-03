import 'dart:io';

import 'package:path/path.dart' as p;

/// HTTP server trên 127.0.0.1 phục vụ thư mục mini app đã giải nén, cộng
/// `/canvaskit/*` lấy từ runtime dùng chung (bundle không chứa CanvasKit).
///
/// Flutter web không chạy được qua `file://` (fetch CanvasKit/wasm, module JS bị
/// chặn), nên mỗi mini app được mở sẽ có một server riêng, với `--base-href /`
/// lúc build.
///
/// Cổng do repository cấp lúc cài và lưu trong registry (duy nhất, không đổi qua
/// các bản cập nhật) vì origin = scheme + host + port: cổng đổi thì localStorage/
/// IndexedDB/cookie của mini app mất. Mỗi app một origin nên dữ liệu tách biệt.
class LocalWebServer {
  LocalWebServer._(this._server, this._root, this._runtimeRoot);

  final HttpServer _server;
  final String _root;
  final String _runtimeRoot;

  Uri get origin => Uri(scheme: 'http', host: _server.address.address, port: _server.port);

  static const _mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.wasm': 'application/wasm',
    '.css': 'text/css; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
    '.woff2': 'font/woff2',
  };

  static const portBase = 41000;
  static const portRange = 1000;

  /// Vị trí bắt đầu dò cổng trống cho [appId] (FNV-1a). Cổng thật do
  /// `MiniAppRepository` cấp, bỏ qua cổng đã thuộc app khác.
  static int preferredPort(String appId) {
    var hash = 0x811c9dc5;
    for (final unit in appId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return portBase + hash % portRange;
  }

  static Future<LocalWebServer> start(
    String rootDirectory, {
    required String runtimeDirectory,
    required int port,
  }) async {
    // Lần mở trước có thể chưa nhả cổng xong (đóng trang rồi mở lại ngay) -> thử lại vài lần.
    for (var attempt = 1;; attempt++) {
      try {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
        final instance = LocalWebServer._(server, p.normalize(rootDirectory), p.normalize(runtimeDirectory));
        server.listen(instance._handle);
        return instance;
      } on SocketException {
        if (attempt == 10) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    var path = Uri.decodeComponent(request.uri.path);
    if (path.isEmpty || path.endsWith('/')) path += 'index.html';
    // CanvasKit nằm trong runtime dùng chung, phần còn lại trong thư mục app.
    final root = path.startsWith('/canvaskit/') ? _runtimeRoot : _root;
    final file = File(p.normalize(p.join(root, path.substring(1))));

    final response = request.response;
    if (!p.isWithin(root, file.path) || !file.existsSync()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    // Cho WebView cache nhưng luôn hỏi lại (no-cache + ETag): file không đổi
    // thì trả 304, WebView dùng bản đã có kèm code đã biên dịch (V8 code cache
    // cho main.dart.js, module cache cho canvaskit.wasm). Không dùng max-age:
    // URL giữ nguyên qua các bản cập nhật (cùng origin, cùng path), chỉ nội
    // dung đổi. Bản mới giải nén ra thư mục mới nên mtime, tức ETag, khác.
    final stat = file.statSync();
    final etag = '"${stat.size.toRadixString(16)}-${stat.modified.microsecondsSinceEpoch.toRadixString(16)}"';
    response.headers
      ..set(HttpHeaders.contentTypeHeader, _mimeTypes[p.extension(file.path)] ?? 'application/octet-stream')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set(HttpHeaders.etagHeader, etag);
    if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
      response.statusCode = HttpStatus.notModified;
      await response.close();
      return;
    }
    response.contentLength = stat.size;
    await response.addStream(file.openRead());
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}
