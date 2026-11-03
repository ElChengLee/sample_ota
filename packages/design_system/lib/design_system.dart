/// Design system dùng chung cho Shell App và các Mini App.
///
/// - `tokens/`: giá trị nguyên thủy (màu, spacing, radius, typography).
/// - `components/`: widget đã được chuẩn hóa, đọc màu từ [Theme] nên tự đổi
///   theo light/dark/brand do package `app_theme` cung cấp.
library;

export 'src/tokens/ds_colors.dart';
export 'src/tokens/ds_radius.dart';
export 'src/tokens/ds_spacing.dart';
export 'src/tokens/ds_typography.dart';
export 'src/components/ds_badge.dart';
export 'src/components/ds_button.dart';
export 'src/components/ds_card.dart';
export 'src/components/ds_empty_state.dart';
export 'src/components/ds_section_header.dart';
