# mini_shop

Mini app Flutter web chạy trong WebView của Shell, tải qua OTA. Dùng chung `design_system`, `app_theme`, `mini_app_bridge` với Shell; routing bằng auto_route.

## Cấu trúc

```
lib/
├── main.dart                 # nơi DUY NHẤT tạo dependency thật (bridge, router, storage)
├── app.dart                  # MiniShopApp, ShopScope (DI), SessionScope (kết quả handshake)
├── config.dart               # kAppId, kBuildVersion, kShowDevTools
├── data/
│   ├── product.dart          # Product, danh mục, productById
│   ├── key_value_store.dart  # interface lưu trữ + bản trong bộ nhớ
│   └── platform/             # localStorage (web) / stub (VM, test) — chọn bằng conditional import
├── state/cart_controller.dart
├── router/app_router.dart    # bảng route duy nhất; deep link dùng matcher của auto_route
├── pages/
│   ├── shop/shop_page.dart + widgets/ (header, product_tile, checkout_bar, dev_tools)
│   └── product_detail_page.dart
└── utils/format.dart         # formatVnd (intl)
```

## Quy ước

- **Không dùng biến global, không gọi `MiniAppBridge.instance` trong page.** Page lấy `ShellApi` và `CartController` qua `ShopScope.of(context)` (hoặc `ShopScope.read(context)` trong event handler), lấy user qua `SessionScope.of(context)`.
- **Gọi Shell qua `ShellApi` có kiểu.** Ví dụ `requestPayment` trả `PaymentResult` (`PaymentSuccess` / `PaymentCancelled` / `PaymentFailed`), xử lý bằng `switch`. Không cast `Map` thô.
  - `openDeepLink`, `showToast`, `close` không ném lỗi.
  - Mọi request có timeout 15s, trừ thanh toán vì phải chờ người dùng.
- **Không có quyền thì không crash.** `session.user` là `null` khi mini app không có quyền `userInfo`. Thiếu quyền `payment` thì nhận `PaymentFailed(permissionDenied: true)`.
- **Dữ liệu lưu sống qua các bản cập nhật.** Đọc phải chịu được dữ liệu hỏng hoặc dữ liệu từ bản cũ (xem `CartController._load`).
- **Thêm route:** chỉ khai trong `AppRouter.routes`. Deep link (`#/path` lúc mở, `navigate` từ Shell) tự khớp theo bảng này.
- **Code chạm `dart:js_interop`** chỉ nằm trong `data/platform/platform_web.dart`, để phần còn lại chạy test được trên VM.
- **"Công cụ test"** chỉ hiện khi debug hoặc build với `--dart-define=DEV_TOOLS=true`. `server/bin/build.dart` bật mặc định; dùng `--no-dev-tools` cho bản phát hành thật.

## Chạy

```bash
flutter run -d chrome                     # standalone, bridge tự mock Shell
flutter test                              # cart, router, luồng mua hàng với FakeShell
dart run build_runner build               # sau khi đổi route
cd ../../server && dart run bin/build.dart mini_shop   # đóng gói OTA
```
