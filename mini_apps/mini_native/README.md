# mini_native

Mini app Flutter **native** (Android/iOS), biên dịch sẵn vào Shell, không tải OTA. Mục đích là kiểm tra khả năng tương thích khi chạy trong Shell: host API, theme, nền tảng, plugin native và điều hướng lồng nhau.

- Chạy độc lập: `flutter run` (dùng host giả `StandaloneHost`).
- Nhúng vào Shell: `import 'package:mini_native/mini_native.dart'`, rồi dùng `MiniNativeApp(host: <MiniNativeHost>)`.
- Test: `flutter test`. Nếu chạy sau proxy công ty, đặt thêm `NO_PROXY=127.0.0.1,localhost`.

Xem README ở thư mục gốc, mục "Mini app native".
