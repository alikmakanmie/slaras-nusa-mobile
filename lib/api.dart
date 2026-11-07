import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';
import 'utils.dart';

/// Error dari API: pesan yang bisa langsung ditampilkan ke pengguna.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Klien HTTP untuk backend ecommerce-api — APLIKASI STAFF ONLY.
///
/// - Envelope respons: {success, message, data, error, meta}.
/// - JWT access token (15 menit) dikirim sebagai Bearer; saat menerima 401,
///   token di-refresh sekali via /auth/refresh lalu request diulang.
/// - Logout menghapus token lokal.
/// - Base URL: utama https://api.alikmakanmie.my.id/api/v1. Bila request
///   gagal total (DNS/timeout/tidak ada koneksi), otomatis fallback ke
///   http://203.175.11.164:2150/api/v1 (IP VPS langsung) untuk sisa sesi.
///   Override manual (layar Login > ikon server) mengunci satu URL.
/// - Semua error transport diubah menjadi ApiException berpesan ramah —
///   pemanggil UI TIDAK PERNAH menerima ClientException/SocketException
///   mentah (itu penyebab "Unhandled Exception" di login 6 Nov 2026).
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  /// Base URL yang sedang dipakai (override manual / primary / fallback).
  String _activeBaseUrl = AppConfig.apiBaseUrl;
  String? _manualOverride;
  bool _usingFallback = false;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kServerOverride = 'server_base_url';

  static const _timeout = Duration(seconds: 20);

  static const _noConnection = ApiException(
    'Tidak bisa terhubung ke server. Periksa koneksi internet, lalu coba lagi.',
  );

  String get baseUrl => _activeBaseUrl;
  String get primaryBaseUrl => AppConfig.apiBaseUrl;
  String get fallbackBaseUrl => AppConfig.fallbackApiBaseUrl;
  bool get isUsingFallback => _usingFallback;
  bool get hasManualOverride => _manualOverride != null;
  String? get manualOverride => _manualOverride;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// Muat token + override server tersimpan. Dipanggil sekali di main().
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _manualOverride = prefs.getString(_kServerOverride);
    _activeBaseUrl = _manualOverride ?? AppConfig.apiBaseUrl;
    _usingFallback = false;
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
  }

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
  }

  /// Kunci server ke satu URL (null/kosong = kembali ke URL utama).
  Future<void> setServerOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final v = url?.trim();
    if (v == null || v.isEmpty) {
      _manualOverride = null;
      await prefs.remove(_kServerOverride);
    } else {
      _manualOverride = v;
      await prefs.setString(_kServerOverride, v);
    }
    _activeBaseUrl = _manualOverride ?? AppConfig.apiBaseUrl;
    _usingFallback = false;
  }

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, access);
    await prefs.setString(_kRefresh, refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && _accessToken != null) {
      h['Authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  Future<Map<String, dynamic>> _decode(http.Response res) async {
    if (res.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  bool _isTransportError(Object e) =>
      e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException;

  /// Satu request HTTP mentah ke satu base URL (tanpa refresh/fallback).
  Future<http.Response> _sendTo(
    String base,
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$base$path').replace(
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
    final payload = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: _headers(auth: auth));
      case 'POST':
        return _http.post(uri, headers: _headers(auth: auth), body: payload);
      case 'PUT':
        return _http.put(uri, headers: _headers(auth: auth), body: payload);
      case 'PATCH':
        return _http.patch(uri, headers: _headers(auth: auth), body: payload);
      case 'DELETE':
        return _http.delete(uri, headers: _headers(auth: auth));
      default:
        throw const ApiException('Metode HTTP tidak dikenal');
    }
  }

  /// Request mentah + timeout + auto-fallback ke IP VPS bila base aktif
  /// gagal total. Error transport selalu jadi ApiException ramah.
  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    try {
      return await _sendTo(
        _activeBaseUrl,
        method,
        path,
        body: body,
        query: query,
        auth: auth,
      ).timeout(_timeout);
    } catch (e) {
      if (!_isTransportError(e)) rethrow;
      // Fallback hanya bila tidak ada override manual dan base aktif
      // bukan fallback itu sendiri.
      if (_manualOverride == null &&
          _activeBaseUrl != AppConfig.fallbackApiBaseUrl) {
        try {
          final res = await _sendTo(
            AppConfig.fallbackApiBaseUrl,
            method,
            path,
            body: body,
            query: query,
            auth: auth,
          ).timeout(_timeout);
          _activeBaseUrl = AppConfig.fallbackApiBaseUrl;
          _usingFallback = true;
          return res;
        } catch (e2) {
          if (_isTransportError(e2)) throw _noConnection;
          rethrow;
        }
      }
      throw _noConnection;
    }
  }

  /// Request JSON dengan auto-refresh token saat 401.
  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    var res = await _send(method, path, body: body, query: query, auth: auth);
    if (res.statusCode == 401 && auth && _refreshToken != null) {
      final ok = await _refresh();
      if (ok) {
        res = await _send(method, path, body: body, query: query, auth: auth);
      }
    }
    final json = await _decode(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = json['error']?.toString() ??
          json['message']?.toString() ??
          'Terjadi kesalahan (${res.statusCode})';
      throw ApiException(msg, res.statusCode);
    }
    if (json['success'] == false) {
      throw ApiException(
        json['error']?.toString() ?? 'Permintaan gagal',
        res.statusCode,
      );
    }
    return json;
  }

  Future<bool> _refresh() async {
    // Cegah refresh ganda bersamaan: semua pemanggil menunggu future yang sama.
    if (_refreshing != null) return _refreshing!;
    final future = _doRefresh();
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _send('POST', '/auth/refresh',
          body: {'refresh_token': refresh}, auth: false);
      if (res.statusCode != 200) {
        await clearTokens();
        return false;
      }
      final json = await _decode(res);
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final access = data['access_token']?.toString() ?? '';
        final newRefresh = data['refresh_token']?.toString() ?? refresh;
        if (access.isEmpty) return false;
        await saveTokens(access, newRefresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return <Map<String, dynamic>>[];
  }

  PagedResult<T> _paged<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final meta = json['meta'];
    var page = 1;
    var totalPages = 1;
    var total = 0;
    if (meta is Map<String, dynamic>) {
      page = parseInt(meta['page'], 1);
      totalPages = parseInt(meta['total_pages'], 1);
      total = parseInt(meta['total']);
    }
    return PagedResult<T>(
      items: _dataList(json).map(fromJson).toList(),
      page: page,
      totalPages: totalPages,
      total: total,
    );
  }

  // ---------------- Auth (staff) ----------------

  Future<({String access, String refresh, User user})> login(
    String email,
    String password,
  ) async {
    final json = await requestJson('POST', '/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    final data = _data(json);
    final access = data['access_token']?.toString() ?? '';
    final refresh = data['refresh_token']?.toString() ?? '';
    if (access.isEmpty) throw const ApiException('Login gagal: token kosong');
    await saveTokens(access, refresh);
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const ApiException('Login gagal: data pengguna kosong');
    }
    return (
      access: access,
      refresh: refresh,
      user: User.fromJson(userJson),
    );
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await requestJson('POST', '/auth/logout',
            body: {'refresh_token': refresh});
      }
    } catch (_) {
      // Abaikan error logout server; token lokal tetap dihapus.
    } finally {
      await clearTokens();
    }
  }

  // ---------------- Profil staf ----------------

  Future<User> getProfile() async {
    final json = await requestJson('GET', '/users/me');
    return User.fromJson(_data(json));
  }

  // ---------------- Katalog (menu) ----------------

  Future<List<Category>> listCategories() async {
    final json = await requestJson('GET', '/categories');
    return _dataList(json).map(Category.fromJson).toList();
  }

  Future<PagedResult<Product>> listProducts({
    String? search,
    String? categoryId,
    int? minPrice,
    int? maxPrice,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (categoryId != null && categoryId.isNotEmpty) {
      query['category_id'] = categoryId;
    }
    if (minPrice != null && minPrice > 0) query['min_price'] = '$minPrice';
    if (maxPrice != null && maxPrice > 0) query['max_price'] = '$maxPrice';
    final json =
        await requestJson('GET', '/products', query: query, auth: false);
    return _paged(json, Product.fromJson);
  }

  Future<Product> getProduct(String id) async {
    final json = await requestJson('GET', '/products/$id', auth: false);
    return Product.fromJson(_data(json));
  }

  // ---------------- Admin: produk & kategori ----------------

  /// Upload foto produk ke POST /upload (admin). Mengembalikan URL publik.
  /// Ikut pola _send: fallback ke IP VPS bila base aktif gagal total,
  /// refresh token sekali bila 401.
  Future<String> uploadImage(List<int> bytes, String filename) async {
    String subtype(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.png')) return 'png';
      if (lower.endsWith('.webp')) return 'webp';
      return 'jpeg';
    }

    Future<http.StreamedResponse> sendTo(String base) async {
      final req = http.MultipartRequest('POST', Uri.parse('$base/upload'));
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $_accessToken';
      }
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', subtype(filename)),
      ));
      return _http.send(req).timeout(const Duration(seconds: 60));
    }

    Future<String> handle(http.StreamedResponse streamed) async {
      final res = await http.Response.fromStream(streamed);
      final json = await _decode(res);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(
          json['error']?.toString() ?? 'Upload gagal (${res.statusCode})',
          res.statusCode,
        );
      }
      final url = (json['data'] as Map<String, dynamic>?)?['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const ApiException(
            'Upload gagal: server tidak mengembalikan URL');
      }
      return url;
    }

    try {
      var streamed = await sendTo(_activeBaseUrl);
      if (streamed.statusCode == 401 && _refreshToken != null) {
        if (await _refresh()) streamed = await sendTo(_activeBaseUrl);
      }
      return await handle(streamed);
    } catch (e) {
      if (!_isTransportError(e)) rethrow;
      if (_manualOverride == null &&
          _activeBaseUrl != AppConfig.fallbackApiBaseUrl) {
        try {
          final streamed = await sendTo(AppConfig.fallbackApiBaseUrl);
          _activeBaseUrl = AppConfig.fallbackApiBaseUrl;
          _usingFallback = true;
          return await handle(streamed);
        } catch (e2) {
          if (_isTransportError(e2)) throw _noConnection;
          rethrow;
        }
      }
      throw _noConnection;
    }
  }

  Future<Product> createProduct(Product product) async {
    final json = await requestJson(
      'POST',
      '/products',
      body: product.toRequestJson(),
    );
    return Product.fromJson(_data(json));
  }

  Future<Product> updateProduct(String id, Product product) async {
    final json = await requestJson(
      'PUT',
      '/products/$id',
      body: product.toRequestJson(),
    );
    return Product.fromJson(_data(json));
  }

  /// Toggle 1-klik Sold Out: PATCH /products/:id/availability
  /// {is_available}. Mengembalikan status ketersediaan baru.
  Future<bool> toggleProductAvailability(String id, bool available) async {
    final json = await requestJson(
      'PATCH',
      '/products/$id/availability',
      body: {'is_available': available},
    );
    final data = _data(json);
    if (data.containsKey('is_available')) {
      return parseBool(data['is_available'], available);
    }
    final product = data['product'];
    if (product is Map<String, dynamic> &&
        product.containsKey('is_available')) {
      return parseBool(product['is_available'], available);
    }
    return available;
  }

  Future<void> deleteProduct(String id) async {
    await requestJson('DELETE', '/products/$id');
  }

  Future<Category> createCategory(Category category) async {
    final json = await requestJson(
      'POST',
      '/categories',
      body: category.toRequestJson(),
    );
    return Category.fromJson(_data(json));
  }

  Future<Category> updateCategory(String id, Category category) async {
    final json = await requestJson(
      'PUT',
      '/categories/$id',
      body: category.toRequestJson(),
    );
    return Category.fromJson(_data(json));
  }

  Future<void> deleteCategory(String id) async {
    await requestJson('DELETE', '/categories/$id');
  }

  // ---------------- Admin: pesanan ----------------

  /// Detail satu order (dipakai layar detail staf; backend mengizinkan
  /// admin & superadmin melihat order mana pun).
  Future<Order> getOrder(String id) async {
    final json = await requestJson('GET', '/orders/$id');
    return Order.fromJson(_data(json));
  }

  Future<PagedResult<Order>> listAllOrders({
    int page = 1,
    int limit = 20,
  }) async {
    final json = await requestJson('GET', '/admin/orders', query: {
      'page': '$page',
      'limit': '$limit',
    });
    return _paged(json, Order.fromJson);
  }

  Future<Order> updateOrderStatus(String id, String status) async {
    final json = await requestJson('PATCH', '/admin/orders/$id/status', body: {
      'status': status,
    });
    return Order.fromJson(_data(json));
  }

  /// Simulasi pembayaran (admin): tandai pembayaran order sebagai lunas
  /// lewat jalur webhook yang sama (idempotent). Dipakai staf di antrean
  /// dapur saat pelanggan sudah bayar tunai/QRIS di kasir.
  /// POST /admin/orders/:id/simulate-payment -> {payment, order}.
  Future<Order> simulatePayment(String orderId) async {
    final json = await requestJson(
      'POST',
      '/admin/orders/$orderId/simulate-payment',
    );
    final data = _data(json);
    final orderJson = data['order'];
    if (orderJson is Map<String, dynamic>) {
      return Order.fromJson(orderJson);
    }
    return Order.fromJson(data);
  }

  // ---------------- Admin: analitik profit ----------------

  /// Analitik profit admin.
  /// GET /admin/analytics/profit?period=today|7d|30d|all
  /// (atau start_date & end_date YYYY-MM-DD). Butuh token admin.
  Future<ProfitAnalytics> getProfitAnalytics({
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, String>{};
    if (period != null) query['period'] = period;
    if (startDate != null) query['start_date'] = startDate;
    if (endDate != null) query['end_date'] = endDate;
    final json = await requestJson(
      'GET',
      '/admin/analytics/profit',
      query: query,
    );
    return ProfitAnalytics.fromJson(_data(json));
  }

  // ---------------- Admin: voucher promo ----------------

  Future<List<Voucher>> listVouchers() async {
    final json = await requestJson('GET', '/admin/vouchers');
    return _dataList(json).map(Voucher.fromJson).toList();
  }

  Future<Voucher> createVoucher(Voucher voucher) async {
    final json = await requestJson(
      'POST',
      '/admin/vouchers',
      body: voucher.toRequestJson(),
    );
    return Voucher.fromJson(_data(json));
  }

  Future<Voucher> updateVoucher(String id, Voucher voucher) async {
    final json = await requestJson(
      'PUT',
      '/admin/vouchers/$id',
      body: voucher.toRequestJson(),
    );
    return Voucher.fromJson(_data(json));
  }

  Future<void> deleteVoucher(String id) async {
    await requestJson('DELETE', '/admin/vouchers/$id');
  }

  /// Validasi voucher publik: POST /vouchers/validate
  /// {code, subtotal} -> {valid, discount_amount, message}.
  Future<({bool valid, int discountAmount, String message})>
      validateVoucher(String code, int subtotal) async {
    final json = await requestJson('POST', '/vouchers/validate',
        body: {'code': code.toUpperCase(), 'subtotal': subtotal},
        auth: false);
    final data = _data(json);
    return (
      valid: parseBool(data['valid'], false),
      discountAmount: parseInt(data['discount_amount']),
      message: parseString(data['message']),
    );
  }

  // ---------------- Publik: loyalitas & antrean ----------------

  /// Cek stamp/poin pelanggan via nomor HP (dine-in/takeaway).
  Future<LoyaltyInfo> getLoyalty(String phone) async {
    final json = await requestJson(
      'GET',
      '/loyalty/${Uri.encodeComponent(phone)}',
      auth: false,
    );
    return LoyaltyInfo.fromJson(_data(json));
  }

  /// Antrean hari ini (publik): pesanan processing + completed 30 mnt
  /// terakhir. Bentuk data backend: List langsung, atau Map
  /// {preparing:[...], ready:[...]}.
  Future<({List<Order> preparing, List<Order> ready})> getOrderQueue() async {
    final json = await requestJson('GET', '/orders/queue', auth: false);
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      List<Order> parseList(dynamic raw) {
        if (raw is! List) return <Order>[];
        return raw
            .whereType<Map<String, dynamic>>()
            .map(Order.fromJson)
            .toList();
      }

      return (
        preparing: parseList(data['preparing']),
        ready: parseList(data['ready']),
      );
    }
    return (preparing: _dataList(json).map(Order.fromJson).toList(), ready: <Order>[]);
  }

  // ---------------- Superadmin: manajemen user ----------------

  Future<PagedResult<User>> listUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
    bool? isActive,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (role != null && role.isNotEmpty) query['role'] = role;
    if (isActive != null) query['is_active'] = isActive ? 'true' : 'false';
    final json =
        await requestJson('GET', '/superadmin/users', query: query);
    return _paged(json, User.fromJson);
  }

  Future<UserStats> getUserStats() async {
    final json = await requestJson('GET', '/superadmin/users/stats');
    return UserStats.fromJson(_data(json));
  }

  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    String phone = '',
    required String role,
  }) async {
    final json = await requestJson('POST', '/superadmin/users', body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
    });
    return User.fromJson(_data(json));
  }

  Future<User> updateUserRole(String id, String role) async {
    final json = await requestJson(
      'PUT',
      '/superadmin/users/$id/role',
      body: {'role': role},
    );
    return User.fromJson(_data(json));
  }

  Future<User> updateUserStatus(String id, bool isActive) async {
    final json = await requestJson(
      'PUT',
      '/superadmin/users/$id/status',
      body: {'is_active': isActive},
    );
    return User.fromJson(_data(json));
  }

  Future<void> deleteUser(String id) async {
    await requestJson('DELETE', '/superadmin/users/$id');
  }

  void dispose() => _http.close();
}
