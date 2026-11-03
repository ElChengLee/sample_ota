{{flutter_js}}
{{flutter_build_config}}

// Font fallback (glyph không có trong font đã đóng gói, vd emoji/CJK) mặc định
// tải từ https://fonts.gstatic.com/s/. Trỏ về local để mini app không gọi ra
// ngoài: chạy được offline, không lộ request tới bên thứ ba. Ký tự thiếu font
// sẽ hiện ô trống; cần thì đặt font vào web/fonts/fallback/ theo cùng đường dẫn.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "fonts/fallback/",
  },
});
