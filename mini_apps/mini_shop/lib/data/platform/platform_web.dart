import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import '../key_value_store.dart';

KeyValueStore createStore() => _LocalStorage();

/// `localStorage` của trình duyệt. Dữ liệu chỉ còn giữa các lần mở nếu origin
/// không đổi, nên Shell serve mỗi mini app ở một cổng cố định.
class _LocalStorage implements KeyValueStore {
  JSObject get _storage => globalContext['localStorage'] as JSObject;

  @override
  String? read(String key) {
    try {
      return _storage.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
    } on Object catch (e) {
      debugPrint('[Storage] đọc $key thất bại: $e');
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      _storage.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
    } on Object catch (e) {
      // Hết quota, storage bị tắt...: không làm hỏng thao tác của người dùng.
      debugPrint('[Storage] ghi $key thất bại: $e');
    }
  }
}

void navigateTopLevel(String url) {
  (globalContext['location'] as JSObject).setProperty('href'.toJS, url.toJS);
}
