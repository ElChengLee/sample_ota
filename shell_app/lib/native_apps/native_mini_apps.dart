import 'package:flutter/material.dart';
import 'package:mini_native/mini_native.dart';

/// Mini app native, biên dịch cùng Shell (không OTA). Muốn cập nhật thì phát
/// hành lại Shell. Thêm app mới: thêm dependency path vào pubspec.yaml rồi
/// thêm một mục vào [kNativeMiniApps], và khai báo quyền của nó trong
/// `server/shell_config.json` (quyền không nằm trong Shell để đổi được qua OTA).
class NativeMiniApp {
  const NativeMiniApp({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Widget Function(MiniNativeHost host) builder;
}

final kNativeMiniApps = <NativeMiniApp>[
  NativeMiniApp(
    id: 'mini_native',
    name: 'Mini Native',
    description: 'Flutter Android/iOS biên dịch sẵn, kiểm tra tương thích với Shell',
    icon: Icons.phone_android,
    builder: (host) => MiniNativeApp(host: host),
  ),
];

NativeMiniApp? findNativeMiniApp(String id) {
  for (final app in kNativeMiniApps) {
    if (app.id == id) return app;
  }
  return null;
}
