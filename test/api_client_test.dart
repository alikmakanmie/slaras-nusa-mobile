import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/config.dart';
import 'package:slaras_nusa_foodlab/models.dart';

/// Tes integrasi ApiClient ke API lokal.
///
/// Jalankan dengan API lokal menyala:
///   flutter test --dart-define API_BASE_URL=http://localhost:8080/api/v1
/// Tanpa API lokal, tes ini gagal koneksi (bukan bug aplikasi).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test memblokir HttpClient nyata secara default; tes integrasi
  // ini memang memanggil API lokal sungguhan, jadi kembalikan ke default.
  HttpOverrides.global = null;
  // SharedPreferences butuh mock channel di lingkungan tes.
  SharedPreferences.setMockInitialValues({});

  test('aliran penuh: login -> produk -> keranjang -> checkout -> order', () async {
    final api = ApiClient();
    addTearDown(api.dispose);

    // 1. Login customer.
    final login = await api.login(
      'customer@ecommerce.local',
      'Customer123!',
    );
    expect(login.user.email, 'customer@ecommerce.local');
    expect(login.access, isNotEmpty);

    // 2. Katalog: kategori + produk tersedia.
    final categories = await api.listCategories();
    expect(categories, isNotEmpty);
    final products = await api.listProducts(limit: 20);
    expect(products.items, isNotEmpty);
    // Pilih produk yang masih ada stoknya (stok DB lokal berkurang
    // setiap kali tes checkout dijalankan — jangan pakai items.first).
    final inStock = products.items.where((p) => p.stock > 0).toList();
    if (inStock.isEmpty) {
      markTestSkipped('semua produk stok habis di DB lokal — reset seeder');
    }
    final first = inStock.first;
    expect(first.price, greaterThan(0));
    expect(first.stock, greaterThan(0));

    // 3. Detail produk.
    final detail = await api.getProduct(first.id);
    expect(detail.id, first.id);

    // 4. Keranjang: tambah 1, ubah jadi 2, lalu cek subtotal.
    await api.addToCart(first.id, 1);
    var cart = await api.getCart();
    expect(cart.totalItems, greaterThanOrEqualTo(1));
    final item = cart.items.firstWhere((i) => i.productId == first.id);
    await api.updateCartQty(item.id, 2);
    cart = await api.getCart();
    final updated =
        cart.items.firstWhere((i) => i.productId == first.id);
    expect(updated.quantity, 2);
    expect(cart.subtotal, greaterThan(0));

    // 5. Alamat: pakai yang default, atau buat bila belum ada.
    var addresses = await api.listAddresses();
    if (addresses.isEmpty) {
      final created = await api.createAddress(const Address(
        id: '',
        label: 'Rumah',
        recipientName: 'Customer Tes',
        phone: '081234567890',
        street: 'Jl. Tes No. 1',
        city: 'Yogyakarta',
        province: 'DIY',
        postalCode: '55165',
        isDefault: true,
      ));
      addresses = [created];
    }
    final address = addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );

    // 6. Checkout QRIS -> order pending + payment_url mock-pay.
    final order = await api.checkout(
      addressId: address.id,
      paymentMethod: 'qris',
      notes: 'tes integrasi flutter',
    );
    expect(order.status, 'pending');
    expect(order.total, greaterThan(0));
    expect(order.payment, isNotNull);
    expect(order.payment!.paymentUrl, contains('/mock-pay/'));

    // 7. Order bisa dibaca kembali + keranjang kosong sesudah checkout.
    final fetched = await api.getOrder(order.id);
    expect(fetched.orderNumber, order.orderNumber);
    cart = await api.getCart();
    expect(cart.totalItems, 0);

    // 8. Profil bisa dibaca.
    final profile = await api.getProfile();
    expect(profile.id, login.user.id);

    // Bersihkan: batalkan order tes agar tidak mengotori data.
    final cancelled = await api.cancelOrder(order.id);
    expect(cancelled.status, 'cancelled');
  });

  test('base URL mengikuti dart-define API_BASE_URL', () {
    const defined = String.fromEnvironment('API_BASE_URL');
    expect(
      AppConfig.apiBaseUrl,
      defined.isEmpty
          ? 'https://api.alikmakanmie.my.id/api/v1'
          : defined,
    );
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
}
