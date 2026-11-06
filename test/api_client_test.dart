import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/config.dart';
import 'package:slaras_nusa_foodlab/models.dart';

/// Tes integrasi ApiClient (APLIKASI STAFF) ke API lokal.
///
/// Jalankan dengan API lokal menyala:
///   flutter test --dart-define API_BASE_URL=http://localhost:8080/api/v1
/// Tanpa API lokal, tes live gagal koneksi (bukan bug aplikasi).
/// Tes fallback/override memakai MockClient (tanpa jaringan).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test memblokir HttpClient nyata secara default; tes integrasi
  // ini memang memanggil API lokal sungguhan, jadi kembalikan ke default.
  HttpOverrides.global = null;
  // SharedPreferences butuh mock channel di lingkungan tes.
  SharedPreferences.setMockInitialValues({});

  test('aliran staf: login admin -> menu -> pesanan -> profit', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    await api.init();

    // 1. Login admin toko.
    final login = await api.login(
      'admin@ecommerce.local',
      'Admin123!',
    );
    expect(login.user.email, 'admin@ecommerce.local');
    expect(login.user.isAdmin, isTrue);
    expect(login.access, isNotEmpty);

    // 1b. Admin DITOLAK di endpoint superadmin (403).
    await expectLater(
      api.listUsers(),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        403,
      )),
    );

    // 2. Menu: kategori + produk tersedia.
    final categories = await api.listCategories();
    expect(categories, isNotEmpty);
    final products = await api.listProducts(limit: 20);
    expect(products.items, isNotEmpty);
    expect(products.items.first.price, greaterThan(0));

    // 3. Pesanan masuk (admin): ada data + order punya jenis pesanan.
    final orders = await api.listAllOrders(limit: 50);
    expect(orders.total, greaterThan(0));
    expect(orders.items.first.orderNumber, isNotEmpty);

    // 3b. Simulasi bayar: order pending -> paid (idempotent).
    final pending = orders.items.where((o) => o.status == 'pending');
    if (pending.isEmpty) {
      markTestSkipped('tidak ada order pending di DB lokal');
    } else {
      final paid = await api.simulatePayment(pending.first.id);
      expect(paid.status, 'paid');
      final paidAgain = await api.simulatePayment(pending.first.id);
      expect(paidAgain.status, 'paid');
    }

    // 4. Dashboard profit admin.
    final profit = await api.getProfitAnalytics(period: '30d');
    expect(profit.summary.grossRevenue, greaterThanOrEqualTo(0));
    expect(profit.summary.netProfit, greaterThanOrEqualTo(0));

    // 5. Profil staf bisa dibaca.
    final profile = await api.getProfile();
    expect(profile.id, login.user.id);

    await api.logout();
  });

  test('aliran superadmin: kelola user end-to-end', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    await api.init();
    await api.login('superadmin@slaras.local', 'SuperAdmin123!');

    // Stats + list.
    final stats = await api.getUserStats();
    expect(stats.total, greaterThanOrEqualTo(6));
    expect(stats.superadmin, greaterThanOrEqualTo(1));
    final users = await api.listUsers(limit: 20);
    expect(users.items.any((u) => u.email == 'admin@ecommerce.local'),
        isTrue);

    // Buat user temp, ubah role, suspend, hapus.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'tes-staf-$stamp@slaras.local';
    final created = await api.createUser(
      name: 'Staf Tes',
      email: email,
      password: 'StafTes123!',
      role: 'admin',
    );
    expect(created.role, 'admin');
    expect(created.isActive, isTrue);
    final asCustomer = await api.updateUserRole(created.id, 'customer');
    expect(asCustomer.role, 'customer');
    final suspended = await api.updateUserStatus(created.id, false);
    expect(suspended.isActive, isFalse);
    await api.deleteUser(created.id);
    final after = await api.listUsers(search: email);
    expect(after.items.where((u) => u.email == email), isEmpty);

    await api.logout();
  });

  test('fallback: primary gagal DNS -> otomatis ke IP VPS', () async {
    SharedPreferences.setMockInitialValues({});
    final mock = MockClient((request) async {
      if (request.url.host == Uri.parse(AppConfig.apiBaseUrl).host) {
        throw const SocketException('Failed host lookup');
      }
      // Fallback (IP VPS) menjawab login.
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'access_token': 'tok-akses',
            'refresh_token': 'tok-refresh',
            'user': {
              'id': 'u1',
              'name': 'Admin Tes',
              'email': 'admin@ecommerce.local',
              'phone': '',
              'role': 'admin',
              'is_active': true,
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(httpClient: mock);
    addTearDown(api.dispose);
    await api.init();
    final login = await api.login('admin@ecommerce.local', 'Admin123!');
    expect(login.user.role, 'admin');
    expect(api.isUsingFallback, isTrue);
    expect(api.baseUrl, AppConfig.fallbackApiBaseUrl);
  });

  test('fallback gagal total -> ApiException ramah (bukan ClientException)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final mock = MockClient((_) async {
      throw const SocketException('Failed host lookup');
    });
    final api = ApiClient(httpClient: mock);
    addTearDown(api.dispose);
    await api.init();
    try {
      await api.login('admin@ecommerce.local', 'Admin123!');
      fail('harus melempar ApiException');
    } on ApiException catch (e) {
      expect(e.message, contains('Tidak bisa terhubung'));
    }
  });

  test('override server manual tersimpan & bisa direset', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient();
    addTearDown(api.dispose);
    await api.init();
    expect(api.hasManualOverride, isFalse);
    await api.setServerOverride('http://203.175.11.164:2150/api/v1');
    expect(api.hasManualOverride, isTrue);
    expect(api.baseUrl, 'http://203.175.11.164:2150/api/v1');
    // Klien baru membaca override yang sama dari SharedPreferences.
    final api2 = ApiClient();
    addTearDown(api2.dispose);
    await api2.init();
    expect(api2.baseUrl, 'http://203.175.11.164:2150/api/v1');
    await api2.setServerOverride(null);
    expect(api2.hasManualOverride, isFalse);
    expect(api2.baseUrl, AppConfig.apiBaseUrl);
  });

  test('base URL mengikuti dart-define API_BASE_URL', () {
    const defined = String.fromEnvironment('API_BASE_URL');
    expect(
      AppConfig.apiBaseUrl,
      defined.isEmpty
          ? 'https://api.alikmakanmie.my.id/api/v1'
          : defined,
    );
    expect(AppConfig.fallbackApiBaseUrl,
        'http://203.175.11.164:2150/api/v1');
  });

  test('resolveImageUrl menangani URL relatif dan absolut', () {
    final origin = AppConfig.apiOrigin;
    expect(
      AppConfig.resolveImageUrl('/uploads/foto.png'),
      '$origin/uploads/foto.png',
    );
    expect(
      AppConfig.resolveImageUrl('https://cdn.example.com/x.jpg'),
      'https://cdn.example.com/x.jpg',
    );
    expect(AppConfig.resolveImageUrl(''), '');
  });

  test('Order.orderTypeLabel: meja / takeaway / delivery', () {
    Order order(String type, String table) => Order(
          id: 'o1',
          orderNumber: 'ORD-X',
          status: 'pending',
          subtotal: 0,
          shippingCost: 0,
          total: 0,
          paymentMethod: 'qris',
          notes: '',
          shippingName: 'Tamu',
          shippingPhone: '',
          shippingAddressText: '',
          orderType: type,
          tableNumber: table,
          items: const [],
          payment: null,
          createdAt: '',
        );
    expect(order('dine_in', '05').orderTypeLabel, 'MEJA 05');
    expect(order('takeaway', '').orderTypeLabel, 'TAKEAWAY');
    expect(order('delivery', '').orderTypeLabel, 'DELIVERY');
  });
}
