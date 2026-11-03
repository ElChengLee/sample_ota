import 'package:flutter/material.dart';
import 'package:mini_app_bridge/mini_app_bridge.dart';

import 'app.dart';
import 'data/key_value_store.dart';
import 'router/app_router.dart';
import 'state/cart_controller.dart';

/// Nơi duy nhất tạo dependency thật. Mọi thứ bên dưới nhận qua constructor
/// hoặc [ShopScope], nên test thay được bằng bản giả.
void main() {
  final ShellApi shell = MiniAppBridge.instance;
  final router = AppRouter();
  // Back do Shell chuyển xuống: maybePop() pop dialog/sheet trước, rồi tới
  // route; trả false khi đang ở màn gốc -> Shell đóng mini app.
  shell.setBackHandler(router.maybePop);
  // Deep link tới mini app đang mở: Shell gửi path xuống, router tự đổi màn.
  shell.setNavigateHandler(router.navigateFromShell);
  runApp(MiniShopApp(shell: shell, router: router, cart: CartController(createPlatformStore())));
}
