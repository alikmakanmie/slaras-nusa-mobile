import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// State global aplikasi (provider):
/// - ThemeState: dark/light mode (persisted).
/// - AuthState: sesi pengguna + token (via ApiClient).
/// - CartState: keranjang belanja (sinkron ke API).
class ThemeState extends ChangeNotifier {
  ThemeState({required bool initialDark}) : _dark = initialDark;

  bool _dark;
  bool get isDark => _dark;

  Future<void> toggle() async {
    _dark = !_dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _dark);
  }

  static Future<ThemeState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeState(initialDark: prefs.getBool('dark_mode') ?? false);
  }
}

class AuthState extends ChangeNotifier {
  AuthState(this._api);

  final ApiClient _api;
  User? _user;
  bool _initialized = false;
  bool _busy = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get initialized => _initialized;
  bool get busy => _busy;

  /// Muat sesi tersimpan: bila ada refresh token, coba refresh lalu ambil profil.
  Future<void> init() async {
    await _api.loadTokens();
    if (_api.hasToken) {
      try {
        _user = await _api.getProfile();
      } catch (_) {
        await _api.clearTokens();
        _user = null;
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.login(email, password);
      _user = result.user;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    _busy = true;
    notifyListeners();
    try {
      await _api.register(name, email, password, phone);
      // Register tidak mengembalikan token -> login otomatis.
      final result = await _api.login(email, password);
      _user = result.user;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _user = await _api.getProfile();
    notifyListeners();
  }

  Future<void> updateProfile(String name, String phone) async {
    _user = await _api.updateProfile(name: name, phone: phone);
    notifyListeners();
  }
}

class CartState extends ChangeNotifier {
  CartState(this._api);

  final ApiClient _api;
  Cart _cart = Cart.empty;
  bool _loading = false;

  /// Mode keranjang: true = sinkron API /cart (member),
  /// false = keranjang lokal di perangkat (tamu).
  bool _loggedIn = false;
  List<LocalCartItem> _localItems = [];

  Cart get cart => _cart;
  bool get loading => _loading;
  bool get isMemberCart => _loggedIn;

  /// Jumlah item & subtotal mengikuti mode aktif (member / tamu).
  int get totalItems =>
      _loggedIn ? _cart.totalItems : _localItems.fold(0, (s, i) => s + i.quantity);
  int get subtotal =>
      _loggedIn ? _cart.subtotal : _localItems.fold(0, (s, i) => s + i.subtotal);
  List<LocalCartItem> get localItems => List.unmodifiable(_localItems);

  void setLoggedIn(bool value) {
    if (_loggedIn == value) return;
    _loggedIn = value;
    if (!value) _cart = Cart.empty;
    notifyListeners();
  }

  static const _kLocalCart = 'local_cart';

  /// Muat keranjang lokal tersimpan + set mode awal.
  Future<void> init({required bool loggedIn}) async {
    _loggedIn = loggedIn;
    await _loadLocal();
    if (loggedIn) await refresh();
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalCart);
    if (raw == null || raw.isEmpty) {
      _localItems = [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _localItems = decoded
            .whereType<Map<String, dynamic>>()
            .map(LocalCartItem.fromJson)
            .toList();
      }
    } catch (_) {
      _localItems = [];
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_localItems.map((i) => i.toJson()).toList());
    await prefs.setString(_kLocalCart, raw);
  }

  /// Tambah produk: member -> API, tamu -> keranjang lokal.
  Future<void> addProduct(Product product, int quantity) async {
    if (_loggedIn) {
      await add(product.id, quantity);
      return;
    }
    await addLocal(product, quantity);
  }

  Future<void> addLocal(Product product, int quantity) async {
    final idx =
        _localItems.indexWhere((i) => i.productId == product.id);
    if (idx >= 0) {
      _localItems[idx] =
          _localItems[idx].copyWith(quantity: _localItems[idx].quantity + quantity);
    } else {
      _localItems.add(LocalCartItem.fromProduct(product, quantity));
    }
    notifyListeners();
    await _saveLocal();
  }

  Future<void> setLocalQty(String productId, int quantity) async {
    final idx = _localItems.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    if (quantity <= 0) {
      _localItems.removeAt(idx);
    } else {
      _localItems[idx] = _localItems[idx].copyWith(quantity: quantity);
    }
    notifyListeners();
    await _saveLocal();
  }

  Future<void> removeLocal(String productId) async {
    _localItems.removeWhere((i) => i.productId == productId);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> clearLocalCart() async {
    _localItems = [];
    notifyListeners();
    await _saveLocal();
  }

  /// Saat member login: dorong isi keranjang lokal ke /cart server,
  /// lalu kosongkan keranjang lokal.
  Future<void> syncLocalToServer() async {
    if (!_loggedIn || _localItems.isEmpty) return;
    final items = List<LocalCartItem>.from(_localItems);
    for (final item in items) {
      try {
        await _api.addToCart(item.productId, item.quantity);
      } catch (_) {
        // Satu item gagal (mis. stok) tidak menggagalkan sisanya.
      }
    }
    await clearLocalCart();
    await refresh();
  }

  Future<void> refresh() async {
    if (!_loggedIn) {
      await _loadLocal();
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      _cart = await _api.getCart();
    } catch (_) {
      _cart = Cart.empty;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    _cart = Cart.empty;
    notifyListeners();
  }

  Future<void> add(String productId, int quantity) async {
    await _api.addToCart(productId, quantity);
    await refresh();
  }

  Future<void> setQty(String itemId, int quantity) async {
    await _api.updateCartQty(itemId, quantity);
    await refresh();
  }

  Future<void> remove(String itemId) async {
    await _api.removeCartItem(itemId);
    await refresh();
  }

  /// Item untuk guest checkout (dari keranjang lokal).
  List<GuestCheckoutItem> get guestCheckoutItems => _localItems
      .map((i) => GuestCheckoutItem(
            productId: i.productId,
            quantity: i.quantity,
            notes: i.notes,
          ))
      .toList();

  /// Baris keranjang seragam (tamu & member) untuk Floating Cart Bar
  /// + sheet edit keranjang.
  List<CartLine> get cartLines {
    if (_loggedIn) {
      return _cart.items
          .map(
            (i) => CartLine(
              key: i.id,
              productId: i.productId,
              name: i.productName,
              price: i.price,
              quantity: i.quantity,
              imageUrl: i.product?.imageUrl ?? '',
            ),
          )
          .toList();
    }
    return _localItems
        .map(
          (i) => CartLine(
            key: i.productId,
            productId: i.productId,
            name: i.name,
            price: i.price,
            quantity: i.quantity,
            imageUrl: i.imageUrl,
          ),
        )
        .toList();
  }

  /// Ubah qty satu baris (member -> API, tamu -> lokal). qty <= 0 = hapus.
  Future<void> setLineQty(CartLine line, int quantity) async {
    if (_loggedIn) {
      await setQty(line.key, quantity);
    } else {
      await setLocalQty(line.productId, quantity);
    }
  }

  Future<void> removeLine(CartLine line) async {
    if (_loggedIn) {
      await remove(line.key);
    } else {
      await removeLocal(line.productId);
    }
  }
}

/// Nomor-nomor order tamu yang tersimpan di perangkat, untuk
/// menu "Pesanan Saya" tanpa login.
class GuestOrdersState extends ChangeNotifier {
  static const _kGuestOrders = 'guest_orders';
  static const _maxSaved = 20;

  List<GuestOrderEntry> _orders = [];

  List<GuestOrderEntry> get orders => List.unmodifiable(_orders);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGuestOrders);
    if (raw == null || raw.isEmpty) {
      _orders = [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _orders = decoded
            .whereType<Map<String, dynamic>>()
            .map(GuestOrderEntry.fromJson)
            .where((e) => e.orderNumber.isNotEmpty)
            .toList();
      }
    } catch (_) {
      _orders = [];
    }
    notifyListeners();
  }

  Future<void> add(String orderNumber) async {
    if (orderNumber.isEmpty) return;
    _orders.removeWhere((e) => e.orderNumber == orderNumber);
    _orders.insert(
      0,
      GuestOrderEntry(
        orderNumber: orderNumber,
        savedAt: DateTime.now().toIso8601String(),
      ),
    );
    if (_orders.length > _maxSaved) {
      _orders = _orders.sublist(0, _maxSaved);
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(String orderNumber) async {
    _orders.removeWhere((e) => e.orderNumber == orderNumber);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kGuestOrders,
      jsonEncode(_orders.map((e) => e.toJson()).toList()),
    );
  }
}

/// Daftar alamat pengguna (dipakai Checkout + halaman Alamat).
class AddressState extends ChangeNotifier {
  AddressState(this._api);

  final ApiClient _api;
  List<Address> _addresses = [];
  bool _loading = false;

  List<Address> get addresses => _addresses;
  bool get loading => _loading;
  Address? get defaultAddress {
    for (final a in _addresses) {
      if (a.isDefault) return a;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _addresses = await _api.listAddresses();
    } catch (_) {
      _addresses = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Address> create(Address address) async {
    final created = await _api.createAddress(address);
    await refresh();
    return created;
  }

  Future<void> remove(String id) async {
    await _api.deleteAddress(id);
    await refresh();
  }

  Future<void> setDefault(String id) async {
    await _api.setDefaultAddress(id);
    await refresh();
  }
}
