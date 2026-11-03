# Sample OTA: Flutter Shell + Mini App (Flutter Web) tải động

Demo kiến trúc "super app":

- **Shell app** (Flutter native, Android/iOS) chứa các module dùng chung: design system, system theme, bridge.
- **Mini app** viết bằng **Flutter web**, được build thành bundle `.zip` và đưa lên OTA server.
- Khi người dùng bấm **"Tải & mở"** trên Shell, Shell sẽ tải bundle, kiểm tra sha256, giải nén, chạy một local HTTP server rồi mở mini app trong **WebView**. Hai bên giao tiếp với nhau qua JS bridge.

```
Sample_OTA/
├── packages/                     # Module dùng chung (Shell + Mini App dùng cùng source)
│   ├── design_system/            # tokens (màu/brand, spacing, radius, typography) + components Ds*
│   ├── app_theme/                # AppTheme.build(), ThemeController, ThemeSpec (serialize JSON)
│   └── mini_app_bridge/          # protocol + MiniAppBridge (phía web) + ShellBridgeHost (phía shell)
├── shell_app/                    # Flutter Android/iOS
│   └── lib/
│       ├── mini_app/             # MiniAppRepository (OTA), LocalWebServer, models
│       └── pages/                # Home, MiniAppPage (WebView), PaymentSheet, ThemeSettings
├── mini_apps/
│   ├── mini_shop/                # Flutter web + mini_app.json, dùng package chung + auto_route
│   ├── mini_game/                # Flutter web, chỉ dùng Flutter SDK (không package chung), tự cài bridge bằng dart:js_interop
│   └── mini_native/              # Flutter Android/iOS, biên dịch sẵn vào Shell (KHÔNG OTA), chạy độc lập được
└── server/                       # OTA server (Dart)
    ├── bin/keygen.dart           # tạo khoá Ed25519 ký manifest (keys/, không commit)
    ├── bin/build.dart            # build web -> bundle zip + runtime CanvasKit -> manifest.json + .sig
    ├── bin/serve.dart            # static server cho manifest + bundle + runtime
    ├── bin/publish_config.dart   # ký + phát hành shell_config.json (quyền, mở chéo, tạm khoá)
    ├── shell_config.json         # config tổng của Shell: file bạn sửa
    └── public/                   # output: "kho lưu trữ" của OTA server
```

## Luồng hoạt động

```
 ┌───────────── Shell (native) ─────────────┐        ┌──── OTA server ────┐
 │ Home ── GET manifest.json + .sig ────────┼──────▶ │ manifest.json(.sig)│
 │   │  verify Ed25519 (kOtaPublicKey)      │        │ bundles/*.zip      │
 │   │  so version với registry.json local  │        │ runtimes/*.zip     │
 │   ▼  (chưa cài / có bản mới)             │        └────────────────────┘
 │ MiniAppRepository.install()              │
 │   runtime CanvasKit (nếu chưa có) + bundle → verify sha256 → giải nén
 │   → cấp cổng (lưu registry) → dọn version cũ / runtime thừa
 │   ▼                                      │
 │ MiniAppPage                              │
 │   LocalWebServer 127.0.0.1:<cổng đã cấp> ◀── WebView load /index.html?mode=dark&brand=forest&seed=2e7d32
 │     /canvaskit/* ← <support>/mini_apps/_runtimes/<engineRev>/
 │   ShellBridgeHost  ◀── JavaScriptChannel "ShellBridge" ── MiniAppBridge.call()
 │                    ──▶ window.__shellDispatch(json)    ──▶ response / event themeChanged
 └──────────────────────────────────────────┘
```

**Bridge API** (`packages/mini_app_bridge/lib/src/protocol.dart`)

| Hướng | Tên | Quyền cần | Mô tả |
|---|---|---|---|
| Mini → Shell | `init` | | Handshake: trả về theme, version, và `user` nếu có quyền `userInfo` |
| Mini → Shell | `getUserInfo` | `userInfo` | Thông tin user đang đăng nhập ở Shell |
| Mini → Shell | `showToast` | | Shell hiện SnackBar native |
| Mini → Shell | `requestPayment` | `payment` | Shell mở bottom sheet thanh toán native, trả về `success`/`cancelled` |
| Mini → Shell | `close` | | Đóng mini app |
| Mini → Shell | `openDeepLink` | `deepLink` | Nhờ Shell mở một deep link `superapp://open/...`, trả `{opened}` |
| Shell → Mini | `navigate` (request) | | Deep link tới mini app đang mở: mini app tự đổi route, không load lại WebView |
| Shell → Mini | `themeChanged` (event) | | `{mode, brand, seed}`: đổi light/dark/brand ở Shell, mini app cập nhật ngay |
| Shell → Mini | `backPressed` (request) | | Mini app tự pop dialog/route rồi trả `{handled}`; Shell chỉ đóng mini app khi `handled: false` |

### Config tổng của Shell (quyền, mở chéo, tạm khoá)

Mọi quyền của mọi mini app (web lẫn native) nằm ở **một file trên server**: `server/shell_config.json`. Sửa file này rồi phát hành là các máy nhận ngay, **không cần build lại Shell, không cần build lại mini app**.

```json
{
  "apps": {
    "mini_shop": {
      "permissions": ["userInfo", "payment", "deepLink"],
      "links": {
        "canOpen":    ["mini_game", "mini_native"],   // phía gọi: được mở những app nào ("*" = mọi app)
        "openableBy": ["*"],                          // phía bị gọi: những app nào được mở mình
        "exported":   ["/", "/product/*"]             // màn cho bên ngoài mở thẳng vào (* = một đoạn, ** ở cuối = phần còn lại)
      }
    },
    "mini_game": { "enabled": false, "permissions": ["userInfo"], "links": { "openableBy": ["mini_shop"] } }
  }
}
```

| Khoá | Ý nghĩa | Mặc định khi thiếu |
|---|---|---|
| `enabled` | `false` = tạm khoá (kill switch): Home hiện "Tạm khoá", mọi đường mở đều bị chặn, app đang mở bị đóng | `true` |
| `permissions` | Quyền bridge / host API: `userInfo`, `payment`, `deepLink` | không quyền nào |
| `links.canOpen` / `openableBy` / `exported` | Quyền điều hướng chéo (bảng dưới) | `[]` / `[]` / `["/"]` |

App không có trong config: vẫn mở được từ Home nhưng không có quyền nào và không mở chéo được.

**Phát hành:**

```bash
cd server
# sửa shell_config.json
dart run bin/publish_config.dart     # kiểm tra + ghi public/shell_config.json + .sig, version tự tăng
```

**Shell nhận config khi nào:** lúc mở app, khi app quay lại từ nền (`AppLifecycleListener.onResume`), và khi kéo làm mới / bấm ⟳ ở Home. Nơi kiểm tra quyền đọc config ngay lúc kiểm tra, nên quyền mới có hiệu lực cả với mini app đang mở. Home hiện `Config quyền: vN` ở cuối trang.

**An toàn:**
- **Ký Ed25519** bằng cùng khoá với manifest. Sửa 1 byte là Shell từ chối và giữ bản đang có.
- **Chống phát lại:** Shell không nhận config có `version` nhỏ hơn bản đang giữ, nên không ai dùng lại được một config cũ (ký hợp lệ) để lấy lại quyền đã thu hồi. `publish_config.dart` tự tăng version.
- **Offline:** config được lưu trên máy (`<app support>/mini_apps/shell_config.json`). Lần đầu chạy mà chưa tải được thì mọi app đều không có quyền (an toàn), và deep link lúc cold start chờ lần tải đầu này.
- **Kiểm tra khi phát hành:** từ chối khoá lạ, quyền lạ, id sai định dạng, mẫu path sai, và `canOpen` mà thiếu quyền `deepLink`.
- `mini_app.json` **không** còn khai `permissions` / `links`; `build.dart` báo lỗi nếu còn.

**Quyền bridge:** `ShellBridgeHost` trả `Permission denied: <quyền>` mà không gọi handler. Mini app native gọi host API (`user`, `requestPayment`, `openDeepLink`) cũng bị kiểm tra cùng bộ quyền: thiếu quyền thì nhận `null` / `false` kèm thông báo.

**Quyền điều hướng chéo (`links`):** quyền `deepLink` chỉ cho mini app *gọi* `openDeepLink`; mở được app nào, màn nào do `links` quyết định:

| Ai gửi link | Điều kiện để được mở |
|---|---|
| Mini app A → mini app B | B có trong `A.canOpen`, **và** A có trong `B.openableBy`, **và** `path` khớp `B.exported` |
| Mini app A → chính A | Luôn được (chỉ cần quyền `deepLink`) |
| Hệ điều hành (intent, cold start) | `path` khớp `B.exported` |
| UI của Shell (Home) | Luôn được |

Ngoài ra app đích bị `enabled: false` thì mọi link tới nó đều bị chặn. Khi bị chặn, Shell báo SnackBar nêu rõ quy tắc nào chặn; `openDeepLink` trả `{opened: false, error: "forbidden"}` cho mini app web, mini app native nhận `false`.

**Cấu hình hiện tại:**
- `mini_shop`: đủ 3 quyền; mở được game và native; ai cũng mở được shop, vào `/` và `/product/*`.
- `mini_game`: chỉ `userInfo`; chỉ `mini_shop` mở được, chỉ vào `/`.
- `mini_native`: đủ 3 quyền; khai mở được shop và game, nhưng game không cho native mở, nên link native → game vẫn bị chặn (cần cả hai phía đồng ý). Muốn cho phép: thêm `"mini_native"` vào `mini_game.links.openableBy` rồi phát hành.

**Code:** `shell_app/lib/policy/shell_config.dart` (`ShellConfig`, `AppPolicy`, `ShellConfigStore`), `shell_app/lib/navigation/link_policy.dart` (`checkLink`), `server/lib/shell_config.dart` (kiểm tra), `server/bin/publish_config.dart`. Test: `shell_app/test/shell_config_test.dart`, `link_policy_test.dart`.

**Routing (auto_route, cả 2 phía):**

| App | Route | Ghi chú |
|---|---|---|
| Shell | `/` → `HomeRoute` | |
| Shell | `/mini-app/:appId?path=…` → `MiniAppRoute` | `MiniAppGuard` chặn khi app chưa cài hoặc đang tạm khoá; `path` được chuyển tiếp cho router của mini app |
| Mini app | `#/` → `ShopRoute` | hash strategy của Flutter web |
| Mini app | `#/product/:productId` → `ProductDetailRoute` | |

- **Deep link từ bên ngoài:** `superapp://open/mini-app/mini_shop?path=/product/p2` (intent-filter Android). Shell dựng Home trước, sau frame đầu giao link cho `DeepLinkHandler` (kiểm tra quyền như mọi link khác), nên stack là `[Home, MiniApp]`. WebView mở `index.html#/product/p2`, và `buildDeepLink` của mini app dựng stack `[Shop, ProductDetail]`. Nhờ vậy Back đi lần lượt: chi tiết → danh sách → đóng mini app → Home.
  ```bash
  adb shell am start -a android.intent.action.VIEW -d "superapp://open/mini-app/mini_shop?path=/product/p2"
  ```
- **Shell ↔ mini app qua deep link:** mọi nguồn (intent của hệ điều hành, nút trên Home, mini app gọi `openDeepLink`) đều đi qua `DeepLinkHandler` của Shell, dùng chung định dạng `SuperAppLinks` trong `mini_app_bridge`:
  - `superapp://open/`: về Home.
  - Mini app chưa mở: kiểm tra đã cài, rồi push `MiniAppRoute`; `path` thành fragment URL. Trong lúc trang đang mở dở (guard đang chạy, page chưa build), các link tiếp theo tới cùng app bị bỏ qua, nên không bao giờ có 2 trang của cùng một app.
  - `superapp://open/native/<id>` (`SuperAppLinks.nativeApp`): mở mini app native. Nếu nó đang mở thì đưa lên trên cùng. Hiện chưa hỗ trợ `path`.
  - Mỗi app chỉ có **một instance** trên stack. Khi link trỏ tới app đang mở, Shell pop các trang phía trên nó, nên mini app phía trên bị đóng và mất state. Ví dụ: stack `[Home, Shop, Game]`, link tới Shop thì stack còn `[Home, Shop]`.
  - Mini app đang mở: đưa nó lên trên cùng (bỏ sheet hoặc mini app khác phía trên), gửi `navigate {path}` xuống. Router của mini app đóng dialog và dựng lại stack `[Shop, ...]`, giỏ hàng và state giữ nguyên. Nếu mini app không trả lời thì Shell load lại WebView với `#path`. Nếu route không tồn tại thì Shell báo SnackBar và giữ nguyên màn.
  - Cold start: dựng `[Home]` rồi mới xử lý link, để mọi link từ hệ điều hành đều qua cùng một lần kiểm tra quyền. Khi app đang chạy, `deepLinkBuilder` giao link cho `DeepLinkHandler` và trả `DeepLink.none`, để auto_route không thay route rồi load lại WebView.
- Page do auto_route khởi tạo nên chỉ nhận được path/query param. Service của Shell (repository, theme) được lấy qua `ShellScope`. Giỏ hàng của mini app nằm trong `CartController`.
- Sau khi sửa route, cần chạy lại generator: `dart run build_runner build --delete-conflicting-outputs` (trong `shell_app/` hoặc `mini_apps/mini_shop/`).

**Navigation trong `MiniAppPage`:**
- Nút Back cứng, thao tác vuốt back và mũi tên ← đều đi qua `PopScope`. Shell gửi `backPressed` cho mini app (timeout 800ms). Nếu mini app không trả lời (bị treo, hoặc chưa cài back handler), Shell đóng luôn mini app. Shell không dùng `webView.canGoBack()`, vì Flutter web tự chèn các mục vào lịch sử trình duyệt nên hàm này gần như luôn trả `true`.
- Nút ✕ và lệnh `close` dùng `popUntil(route của MiniAppPage)` rồi `pop`, nên đóng đúng mini app kể cả khi đang có sheet hoặc dialog của Shell nằm phía trên.
- `onNavigationRequest` chỉ cho phép điều hướng trong origin local của mini app. Link ngoài bị chặn, vì trang ngoài cũng sẽ truy cập được `window.ShellBridge`.

**Theme đồng nhất:** cả hai bên build `ThemeData` bằng cùng hàm `AppTheme.build(brand, brightness)` từ `app_theme`. Shell chỉ cần gửi `ThemeSpec` (`{mode, brand, seed}`) qua bridge. Mini app không dùng package chung (như `mini_game`) thì dựng `ColorScheme.fromSeed(seed)`, không cần biết bảng màu từng brand. Theme ban đầu cũng được truyền qua query URL để frame đầu tiên đã đúng màu.

## Mini app native (biên dịch sẵn, không OTA)

`mini_apps/mini_native` là project Flutter có `android/` và `ios/`, dùng để kiểm tra một mini app viết native có chạy ổn trong Shell không.

- **Chạy độc lập:** `cd mini_apps/mini_native && flutter run`. Lúc này app dùng `StandaloneHost` (host giả: toast, dialog thanh toán).
- **Trong Shell:** Shell khai dependency `path: ../mini_apps/mini_native`, đăng ký app trong `shell_app/lib/native_apps/native_mini_apps.dart` (quyền của nó khai trong `server/shell_config.json` như app web) và mở nó ở route `/native/:appId`. Deep link: `superapp://open/native/mini_native`.
- **Giao tiếp:** không có JS bridge. `NativeMiniAppPage` của Shell implement `MiniNativeHost` (user, toast, thanh toán, deep link, đóng), và mini app gọi thẳng hàm Dart.
- **Theme:** mini app không tạo `MaterialApp`, nên theme lấy trực tiếp từ Shell và đổi ngay khi Shell đổi theme.
- **Điều hướng:** mini app có `Navigator` riêng. Back sẽ pop màn bên trong trước, khi không còn màn nào mới đóng mini app.
- **Plugin:** mini app dùng `shared_preferences`. Plugin của mini app được build vào Shell, có trong `GeneratedPluginRegistrant`. Nếu thấy `MissingPluginException` thì cần build lại Shell (hot reload không đủ).
- **Đánh đổi so với mini app web:** chạy nhanh và giao diện native hoàn toàn. Đổi lại, muốn cập nhật thì phải phát hành lại Shell. Phiên bản của các package dùng chung phải tương thích với Shell, vì pub chỉ chọn một phiên bản cho cả hai. Mini app chạy cùng tiến trình và có toàn quyền như Shell, nên không có lớp kiểm tra quyền.

## Chạy demo

Cần Flutter 3.47 trở lên.

```bash
# 0. (Một lần) Tạo khoá ký manifest. Nếu tạo khoá mới, dán public key in ra vào
#    kOtaPublicKey trong shell_app/lib/config.dart.
cd server
dart pub get
dart run bin/keygen.dart

# 1. Build mini app -> public/bundles/*.zip, public/runtimes/*.zip, manifest.json + .sig
dart run bin/build.dart            # hoặc: dart run bin/build.dart mini_shop
dart run bin/publish_config.dart   # config quyền tổng (chạy lại mỗi khi sửa shell_config.json)

# 2. Chạy OTA server (giữ terminal này mở)
dart run bin/serve.dart            # cổng 8080

# 3. Chạy Shell (emulator hoặc máy thật cắm USB). Shell mặc định gọi http://localhost:8080.
#    Mỗi lần build debug, Gradle tự chạy `adb reverse tcp:8080 tcp:8080` cho mọi thiết bị đang cắm
#    (task adbReverseOtaServer). Nếu cắm lại cáp mà không build lại thì chạy tay lệnh đó.
cd ../shell_app
flutter run                        # hoặc Run main.dart trong Android Studio
# Debug qua IP LAN: flutter run --dart-define=MINI_APP_SERVER=http://<IP-máy-dev>:8080
# Release: bắt buộc HTTPS: --dart-define=MINI_APP_SERVER=https://cdn.example.com/ota
```

Sau đó trên Shell: bấm **"Tải & mở"** ở Mini Shop, đổi theme hoặc brand (ở Home hoặc qua icon 🎨 trên AppBar của mini app), thêm món và bấm **Thanh toán**.

### Demo cập nhật OTA

1. Sửa UI trong `mini_apps/mini_shop/lib/...` và tăng `version: 1.0.1` trong `mini_apps/mini_shop/pubspec.yaml`.
2. Chạy lại `dart run bin/build.dart`. Server không cần restart.
3. Trên Shell, kéo để refresh: tile hiện `v1.0.0 → v1.0.1`. Bấm **"Cập nhật & mở"** để Shell tải bản mới và tự xóa version cũ.

Không cần build lại hay cài lại Shell.

### Dev mini app độc lập (không cần Shell)

```bash
cd mini_apps/mini_shop
flutter run -d chrome
```

Khi không có `window.ShellBridge`, `MiniAppBridge` tự chuyển sang **mock mode** (badge `standalone`) nên vẫn dev UI bình thường. Có thể thử theme qua URL: `...?mode=dark&brand=sunset` (mini_shop) hoặc `...?mode=dark&seed=e65100` (mini_game).

## Ghi chú kỹ thuật

- **Vì sao dùng local HTTP server thay cho `file://`?** Flutter web cần `fetch` CanvasKit/wasm và load module JS, mà các thao tác này bị chặn trên `file://`. Vì vậy mỗi mini app được serve ở root (`--base-href /`) trên `127.0.0.1`. Server tự đóng khi rời trang.
- **Cổng local:** `MiniAppRepository` cấp cổng lúc cài, trong dải 41000–41999. Nó dò từ vị trí hash của appId và bỏ qua cổng đã cấp cho app khác, rồi lưu cổng vào `registry.json`. Khi cập nhật, app giữ nguyên cổng cũ. Origin không đổi nên localStorage và IndexedDB được giữ lại, và mỗi mini app có dữ liệu tách biệt.
- **CanvasKit dùng chung (runtime):** `build.dart` tách `canvaskit/` khỏi bundle và đóng gói riêng thành `runtimes/canvaskit-<engineRevision>.zip`. Gói này chỉ gồm `canvaskit.*` (dùng trên iOS) và `chromium/canvaskit.*` (dùng trên Android WebView). Các biến thể skwasm, wimp, webparagraph và file `.symbols` bị bỏ, vì bản build dart2js không dùng tới. Bundle giảm từ khoảng 15,6 MB xuống 1,4–1,7 MB, còn runtime khoảng 5,3 MB và chỉ tải một lần cho mọi app build cùng bản Flutter. `LocalWebServer` phục vụ `/canvaskit/*` từ `_runtimes/<rev>/`. Runtime không còn app nào dùng sẽ tự bị xoá.
- **Font offline:** `design_system` đóng gói Roboto (Regular, Medium, Bold; lấy từ Android SDK, giấy phép Apache 2.0) và `AppTheme` dùng font này. `mini_game` cũng tự đóng gói Roboto. `web/flutter_bootstrap.js` đặt `fontFallbackBaseUrl: "fonts/fallback/"`, nên Flutter web không còn gọi `fonts.gstatic.com`. Ký tự không có trong font (emoji, CJK) sẽ hiện ô trống; nếu cần thì đặt font vào `web/fonts/fallback/`. Vì vậy `mini_shop` đã thay emoji 👋 bằng icon.
- **An toàn:**
  - `manifest.json` được ký Ed25519 (`manifest.json.sig`). Shell verify bằng `kOtaPublicKey` trước khi parse, và manifest chứa sha256 của mọi bundle và runtime, nên toàn bộ chuỗi tải về đều được bảo vệ.
  - Giải nén có chặn zip-slip và giải nén vào thư mục tạm trước khi rename.
  - Mọi thao tác ghi registry chạy tuần tự (mutex) và ghi kiểu atomic (file tạm rồi rename).
  - Bridge kiểm tra quyền theo từng mini app.
  - WebView chỉ được điều hướng trong origin local.
- **Transport:**
  - Release chỉ chấp nhận HTTPS, trừ loopback. Điều kiện này được kiểm tra trong `MiniAppRepository`, Android `network_security_config.xml` (HTTP chỉ cho `127.0.0.1`, `localhost`, `10.0.2.2`) và iOS ATS (`NSAllowsLocalNetworking`, đã bỏ `NSAllowsArbitraryLoads`).
  - Bản debug Android ghi đè config để cho phép HTTP tới IP LAN.
- **Test:** `cd shell_app && flutter test` (sau proxy công ty thì đặt `NO_PROXY=127.0.0.1,localhost`). Bộ test kiểm tra chữ ký thật của `server/public`, cài song song, cấp cổng, dọn runtime, `LocalWebServer` và quyền bridge.
