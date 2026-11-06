import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// State global APLIKASI STAFF:
/// - ThemeState: dark/light mode (persisted).
/// - AuthState: sesi staf (admin / superadmin) + token (via ApiClient).
///
/// Akun customer DITOLAK: aplikasi ini khusus staf. Login maupun sesi
/// tersimpan milik customer langsung di-logout dengan pesan tegas.
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

  /// true hanya untuk admin toko & superadmin (customer sudah ditolak
  /// saat login/init sehingga _user tidak pernah berisi customer).
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isSuperAdmin => _user?.isSuperAdmin ?? false;
  bool get initialized => _initialized;
  bool get busy => _busy;

  static const accessDeniedMessage =
      'Akses Ditolak: Aplikasi ini khusus untuk Admin & Superadmin '
      'SLARAS NUSA FOODLAB';

  /// Muat sesi tersimpan: bila ada refresh token, coba refresh lalu ambil
  /// profil. Sesi customer langsung dibersihkan (ditolak).
  Future<void> init() async {
    await _api.init();
    if (_api.hasToken) {
      try {
        final profile = await _api.getProfile();
        if (profile.isCustomer) {
          await _api.clearTokens();
          _user = null;
        } else {
          _user = profile;
        }
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
      if (result.user.isCustomer) {
        // Tolak akun customer: hapus token yang telanjur tersimpan.
        await _api.clearTokens();
        _user = null;
        throw const ApiException(accessDeniedMessage);
      }
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
}
