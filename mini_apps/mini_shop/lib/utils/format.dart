import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi');

/// `45000` -> `45.000đ`.
String formatVnd(int value) => '${_vnd.format(value)}đ';
