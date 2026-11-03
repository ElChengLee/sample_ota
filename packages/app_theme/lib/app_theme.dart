/// System theme dùng chung cho Shell và Mini App.
///
/// Shell giữ [ThemeController] làm nguồn sự thật; Mini App nhận [ThemeSpec]
/// (đã serialize JSON) qua bridge và build lại cùng một [ThemeData] bằng
/// [AppTheme.build], nên giao diện 2 bên luôn đồng nhất.
library;

export 'src/app_theme_builder.dart';
export 'src/theme_controller.dart';
export 'src/theme_spec.dart';
