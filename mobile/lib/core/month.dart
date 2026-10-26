import 'package:intl/intl.dart';

/// Menggeser bulan berformat "YYYY-MM" sebanyak [delta] bulan.
/// Contoh: shiftMonth('2026-12', 1) menghasilkan '2027-01'.
String shiftMonth(String month, int delta) {
  final parts = month.split('-');
  final shifted = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta);

  return DateFormat('yyyy-MM').format(shifted);
}