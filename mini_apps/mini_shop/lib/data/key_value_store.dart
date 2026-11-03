import 'platform/platform_stub.dart' if (dart.library.js_interop) 'platform/platform_web.dart' as platform;

/// Lưu trữ key-value đơn giản. Code nghiệp vụ chỉ biết interface này, nên chạy
/// test được trên VM (không có `localStorage`).
abstract interface class KeyValueStore {
  String? read(String key);

  void write(String key, String value);
}

class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;
}

/// Bản cho nền tảng đang chạy: `localStorage` trên web, bộ nhớ ở nơi khác.
KeyValueStore createPlatformStore() => platform.createStore();

/// Điều hướng cả trang sang [url]. Dùng để kiểm tra Shell chặn điều hướng ra ngoài.
void navigateTopLevel(String url) => platform.navigateTopLevel(url);
