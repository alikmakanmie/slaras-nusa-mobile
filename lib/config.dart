/// Konfigurasi aplikasi.
///
/// Base URL API produksi. Untuk pengujian lokal, build/run dengan:
///   flutter run --dart-define API_BASE_URL=http://localhost:8080/api/v1
/// Di emulator Android, localhost host adalah http://10.0.2.2:8080/api/v1
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.alikmakanmie.my.id/api/v1',
  );

  /// URL cadangan: IP VPS langsung (tanpa domain/Cloudflare). Dipakai
  /// otomatis bila URL utama gagal (DNS/timeout) dan bisa dipilih manual
  /// di layar Login. Port 2150 = NAT publik VPS -> API :8080 di dalam.
  static const String fallbackApiBaseUrl =
      'http://203.175.11.164:2150/api/v1';

  /// Origin API (tanpa path /api/v1), dipakai untuk menyelesaikan image_url
  /// relatif seperti "/uploads/xxx.png" yang disajikan backend.
  static String get apiOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String resolveImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final v = raw.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('/')) return '$apiOrigin$v';
    return '$apiOrigin/$v';
  }
}
