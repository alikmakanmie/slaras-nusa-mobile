/// Utilitas kecil: format Rupiah, tanggal, dan parsing angka defensif.
String formatRupiah(num value) {
  final isNeg = value < 0;
  var n = value.abs().round();
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromRight = digits.length - i;
    buf.write(digits[i]);
    if (fromRight > 1 && fromRight % 3 == 1) buf.write('.');
  }
  return '${isNeg ? '-Rp' : 'Rp'}${buf.toString()}';
}

String formatTanggal(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final d = dt.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${bulan[d.month - 1]} ${d.year} $hh:$mm';
}

int parseInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String parseString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

bool parseBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

double parseDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String slugify(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
