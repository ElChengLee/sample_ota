# mini_game

Mini app thứ hai của demo, viết bằng **Flutter thuần**: chỉ phụ thuộc Flutter SDK.

Khác với `mini_shop`, app này không dùng `design_system`, `app_theme`, `mini_app_bridge` hay `auto_route`.
Nó chứng minh rằng bất kỳ app Flutter web nào cũng chạy được trong Shell, miễn là nói đúng giao thức JSON:

| File | Vai trò |
|---|---|
| `lib/shell_bridge.dart` | Bridge tối giản qua `dart:js_interop`: `window.ShellBridge.postMessage` / `window.__shellDispatch` |
| `lib/app_theme.dart` | Đọc `{mode, seed}` (query URL + event `themeChanged`), dựng `ColorScheme.fromSeed`. Font Roboto đóng gói trong `fonts/` |
| `lib/memory_game_page.dart` | Game lật thẻ 4x4, lưu kỷ lục bằng `localStorage` |

Quyền do config tổng của Shell quyết định (`server/shell_config.json`, mục `mini_game`): chỉ `userInfo` (để chào tên), gọi `requestPayment` sẽ bị Shell từ chối. Điều hướng: chỉ `mini_shop` được mở game, và chỉ vào màn gốc `/`.

Bridge xử lý: `init`, `showToast`, `close` (gọi lên), `backPressed`, `navigate` (Shell gọi xuống), event `themeChanged`.
Chạy độc lập (`flutter run -d chrome`) thì bridge tự chuyển sang mock mode.

Build bundle: `cd ../../server && dart run bin/build.dart mini_game`.
