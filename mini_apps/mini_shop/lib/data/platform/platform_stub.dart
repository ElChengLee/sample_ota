import 'package:flutter/foundation.dart';

import '../key_value_store.dart';

/// Ngoài web (test trên VM): lưu trong bộ nhớ, không điều hướng trang.
KeyValueStore createStore() => InMemoryKeyValueStore();

void navigateTopLevel(String url) => debugPrint('[Platform] bỏ qua điều hướng tới $url (không phải web)');
