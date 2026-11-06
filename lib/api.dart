import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
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

/// Klien HTTP untuk backend ecommerce-api.
///
/// - Envelope respons: {success, message, data, error, meta}.
/// - JWT access token (15 menit) dikirim sebagai Bearer; saat menerima 401,
///   token di-refresh sekali via /auth/refresh lalu request diulang.
/// - Logout menghapus token lokal.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  String get baseUrl => AppConfig.apiBaseUrl;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
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

  /// Satu request HTTP mentah (tanpa refresh otomatis).
  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
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

  // ---------------- Auth ----------------

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

  Future<User> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    final json = await requestJson('POST', '/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
    }, auth: false);
    final data = _data(json);
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const ApiException('Registrasi gagal: data pengguna kosong');
    }
    return User.fromJson(userJson);
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

  // ---------------- Profil & Alamat ----------------

  Future<User> getProfile() async {
    final json = await requestJson('GET', '/users/me');
    return User.fromJson(_data(json));
  }

  Future<User> updateProfile({required String name, required String phone}) async {
    final json = await requestJson('PUT', '/users/me', body: {
      'name': name,
      'phone': phone,
    });
    return User.fromJson(_data(json));
  }

  Future<List<Address>> listAddresses() async {
    final json = await requestJson('GET', '/users/me/addresses');
    return _dataList(json).map(Address.fromJson).toList();
  }

  Future<Address> createAddress(Address address) async {
    final json = await requestJson(
      'POST',
      '/users/me/addresses',
      body: address.toRequestJson(),
    );
    return Address.fromJson(_data(json));
  }

  Future<void> deleteAddress(String id) async {
    await requestJson('DELETE', '/users/me/addresses/$id');
  }

  Future<Address> setDefaultAddress(String id) async {
    final json = await requestJson('PUT', '/users/me/addresses/$id/default');
    return Address.fromJson(_data(json));
  }

  // ---------------- Katalog ----------------

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
    final json = await requestJson('GET', '/products', query: query, auth: false);
    return _paged(json, Product.fromJson);
  }

  Future<Product> getProduct(String id) async {
    final json = await requestJson('GET', '/products/$id', auth: false);
    return Product.fromJson(_data(json));
  }

  // ---------------- Keranjang ----------------

  Future<Cart> getCart() async {
    final json = await requestJson('GET', '/cart');
    return Cart.fromJson(_data(json));
  }

  Future<CartItem> addToCart(String productId, int quantity) async {
    final json = await requestJson('POST', '/cart/items', body: {
      'product_id': productId,
      'quantity': quantity,
    });
    return CartItem.fromJson(_data(json));
  }

  Future<void> updateCartQty(String itemId, int quantity) async {
    await requestJson('PUT', '/cart/items/$itemId', body: {
      'quantity': quantity,
    });
  }

  Future<void> removeCartItem(String itemId) async {
    await requestJson('DELETE', '/cart/items/$itemId');
  }

  // ---------------- Order ----------------

  Future<Order> checkout({
    required String addressId,
    required String paymentMethod,
    String notes = '',
  }) async {
    final json = await requestJson('POST', '/orders/checkout', body: {
      'address_id': addressId,
      'payment_method': paymentMethod,
      'notes': notes,
    });
    return Order.fromJson(_data(json));
  }

  // ---------------- Guest Checkout (tanpa login) ----------------

  /// Guest checkout publik (tanpa JWT).
  /// POST /orders/guest-checkout — respons data: {order: {...}, payment: {...}}.
  Future<Order> guestCheckout({
    required List<GuestCheckoutItem> items,
    required String customerName,
    String? customerPhone,
    required String orderType, // dine_in | takeaway | delivery
    String? tableNumber,
    String? notes,
    Map<String, String>? deliveryAddress,
    required String paymentMethod, // qris | va
  }) async {
    final body = <String, dynamic>{
      'items': items.map((i) => i.toJson()).toList(),
      'customer_name': customerName,
      'order_type': orderType,
      'payment_method': paymentMethod,
    };
    if (customerPhone != null && customerPhone.isNotEmpty) {
      body['customer_phone'] = customerPhone;
    }
    if (tableNumber != null && tableNumber.isNotEmpty) {
      body['table_number'] = tableNumber;
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (deliveryAddress != null) body['delivery_address'] = deliveryAddress;
    final json = await requestJson(
      'POST',
      '/orders/guest-checkout',
      body: body,
      auth: false,
    );
    return Order.fromJson(_guestOrderJson(_data(json)));
  }

  /// Lacak order tamu publik (tanpa JWT).
  /// GET /orders/track/:order_number — respons data: order (+ items, total).
  Future<Order> trackOrder(String orderNumber) async {
    final json = await requestJson(
      'GET',
      '/orders/track/${Uri.encodeComponent(orderNumber)}',
      auth: false,
    );
    return Order.fromJson(_guestOrderJson(_data(json)));
  }

  /// Normalisasi respons guest: data bisa berupa order langsung,
  /// atau {order: {...}, payment: {...}} (payment dipisah).
  Map<String, dynamic> _guestOrderJson(Map<String, dynamic> data) {
    final orderJson = data['order'];
    if (orderJson is Map<String, dynamic>) {
      final merged = Map<String, dynamic>.from(orderJson);
      final payment = data['payment'];
      if (payment is Map<String, dynamic> && merged['payment'] == null) {
        merged['payment'] = payment;
      }
      return merged;
    }
    return data;
  }

  Future<PagedResult<Order>> listOrders({int page = 1, int limit = 20}) async {
    final json = await requestJson('GET', '/orders', query: {
      'page': '$page',
      'limit': '$limit',
    });
    return _paged(json, Order.fromJson);
  }

  Future<Order> getOrder(String id) async {
    final json = await requestJson('GET', '/orders/$id');
    return Order.fromJson(_data(json));
  }

  Future<Order> cancelOrder(String id) async {
    final json = await requestJson('POST', '/orders/$id/cancel');
    return Order.fromJson(_data(json));
  }

  // ---------------- Admin ----------------

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

  /// Halaman simulasi pembayaran (MockPayPage). Dibuka di browser eksternal;
  /// halaman ini TIDAK mengubah status order — status berubah lewat webhook
  /// gateway (server-side). Aplikasi mem-poll GET /orders/:id sampai paid.
  String mockPayUrl(String transactionId) => '$baseUrl/mock-pay/$transactionId';

  void dispose() => _http.close();
}
