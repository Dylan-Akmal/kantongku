import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String formatRupiah(num value) => _rupiah.format(value);

/// "2026-10-18" menjadi "18 Okt 2026".
String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  return DateFormat('d MMM y', 'id_ID').format(DateTime.parse(iso));
}

/// Tanggal hari ini (zona waktu perangkat) dalam format YYYY-MM-DD.
String todayLocal() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Bulan berjalan dalam format YYYY-MM.
String currentMonth() => DateFormat('yyyy-MM').format(DateTime.now());

/// "2026-10" menjadi "Oktober 2026".
String formatMonthLabel(String month) {
  return DateFormat('MMMM y', 'id_ID').format(DateTime.parse('$month-01'));
}