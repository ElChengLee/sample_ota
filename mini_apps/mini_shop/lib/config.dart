import 'package:flutter/foundation.dart';

/// Trùng `id` trong mini_app.json, dùng để tạo deep link tới chính mini app này.
const kAppId = 'mini_shop';

/// Version build-time, script build truyền vào qua `--dart-define=APP_VERSION=...`.
const kBuildVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// Khối "Công cụ test" (đóng mini app, treo JS, deep link chéo...). Chỉ hiện
/// khi chạy debug, hoặc khi build với `--dart-define=DEV_TOOLS=true`
/// (`server/bin/build.dart` bật mặc định cho demo, tắt bằng `--no-dev-tools`).
const kShowDevTools = kDebugMode || bool.fromEnvironment('DEV_TOOLS');
