import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Giữ sẵn một WebView chưa dùng để mở mini app không phải chờ tạo WebView.
///
/// Tạo WebView native + load trang đầu (dựng renderer process) tốn ~150ms ở
/// lần đầu trong process trên máy tầm trung, các lần sau ~60ms. Pool tạo
/// trước lúc rảnh (Home vừa hiện, mini app vừa đóng) nên lúc người dùng bấm
/// mở thì đã có sẵn.
///
/// Mỗi WebView chỉ dùng cho một lần mở: không trả lại pool, tránh lộ state
/// (JS channel, history, origin) của mini app trước sang mini app sau.
class WebViewPool {
  WebViewController? _spare;

  /// Tạo WebView dự phòng nếu chưa có. Gọi lúc UI rảnh.
  void warmUp() {
    if (_spare != null) return;
    // Load một trang trống để Chromium dựng luôn renderer process (phần đắt
    // nhất của lần load đầu), không chỉ tạo object WebView.
    _spare = WebViewController()..loadHtmlString('<!DOCTYPE html><html></html>');
    debugPrint('[WebViewPool] đã tạo sẵn WebView');
  }

  /// WebView mới để dùng ngay; lấy bản tạo sẵn nếu có.
  WebViewController take() {
    final controller = _spare ?? WebViewController();
    _spare = null;
    return controller;
  }
}
