import 'package:mini_app_bridge/mini_app_bridge.dart';

const kShellVersion = '1.0.0';

/// Public key Ed25519 (base64) của OTA server, dùng verify `manifest.json.sig`.
/// Tạo bằng `cd server && dart run bin/keygen.dart`; private key nằm ở
/// `server/keys/` (không commit). Đổi khoá thì phải phát hành lại Shell.
const kOtaPublicKey = 'LIz+nldDt0f9+55QijHy2RIP/w/5VRXBdU3lP067D/4=';

/// URL của OTA server (thư mục `server/`).
///
/// Mặc định dùng localhost cho cả emulator lẫn máy thật: cổng 8080 được chuyển
/// về máy dev qua USB bằng `adb reverse tcp:8080 tcp:8080`. Gradle tự chạy lệnh
/// này trước mỗi lần build debug (task `adbReverseOtaServer` trong
/// android/app/build.gradle.kts) nên Run từ Android Studio là đủ.
///
/// Release: dùng URL HTTPS thật (HTTP chỉ được phép với loopback):
///   flutter build apk --dart-define=MINI_APP_SERVER=https://cdn.example.com/ota
///
/// Ghi đè khi cần (vd dùng IP LAN):
///   flutter run --dart-define=MINI_APP_SERVER=http://192.168.1.10:8080
String get miniAppServerUrl {
  const override = String.fromEnvironment('MINI_APP_SERVER');
  if (override.isNotEmpty) return override;
  return 'http://localhost:8080';
}

/// User giả lập đang đăng nhập trong Shell, được chia sẻ cho Mini App qua bridge.
const kDemoUser = MiniAppUser(id: 'u_1024', name: 'Nguyễn Văn Bình', phone: '0912345678');
