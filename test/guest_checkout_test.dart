import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/config.dart';
import 'package:slaras_nusa_foodlab/models.dart';
import 'package:slaras_nusa_foodlab/state.dart';

/// Tes Guest Checkout (publik, tanpa login) ke API lokal.
///
/// Jalankan dengan API lokal menyala:
///   flutter test --dart-define API_BASE_URL=http://localhost:8080/api/v1
/// Bila endpoint guest belum live di backend (404), tes dilewati
/// (markTestSkipped) — bukan dianggap lolos diam-diam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test memblokir HttpClient nyata secara default; tes integrasi
  // ini memang memanggil API lokal sungguhan, jadi kembalikan ke default.
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  test('katalog bisa dibaca tanpa login', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    final categories = await api.listCategories();
    expect(categories, isNotEmpty);
    final products = await api.listProducts(limit: 5);
    expect(products.items, isNotEmpty);
    expect(products.items.first.price, greaterThan(0));
  });

  test('guest checkout dine-in + track sampai pending', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    final products = await api.listProducts(limit: 20);
    // Pilih produk yang masih ada stoknya (stok DB lokal berkurang
    // setiap kali tes checkout dijalankan — jangan pakai items.first).
    final inStock = products.items.where((p) => p.stock > 0).toList();
    if (inStock.isEmpty) {
      markTestSkipped('semua produk stok habis di DB lokal — reset seeder');
    }
    final product = inStock.first;
    late final Order order;
    try {
      order = await api.guestCheckout(
        items: [
          GuestCheckoutItem(
            productId: product.id,
            quantity: 1,
            notes: 'less sugar',
          ),
        ],
        customerName: 'Tamu Tes DineIn',
        orderType: 'dine_in',
        tableNumber: 'Meja 04',
        paymentMethod: 'qris',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        markTestSkipped('endpoint guest-checkout belum live (404)');
      }
      rethrow;
    }
    expect(order.orderNumber, startsWith('ORD-'));
    expect(order.status, 'pending');
    expect(order.payment, isNotNull);
    expect(order.payment!.paymentUrl, contains('/mock-pay/'));
    expect(order.payment!.qrString, isNotEmpty);
    expect(order.items, isNotEmpty);
    expect(order.items.first.notes, 'less sugar');

    // Lacak publik dengan nomor order yang sama.
    final tracked = await api.trackOrder(order.orderNumber);
    expect(tracked.orderNumber, order.orderNumber);
    expect(tracked.status, 'pending');
    expect(tracked.total, order.total);
  });

  test('guest checkout takeaway + track', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    final products = await api.listProducts(limit: 20);
    // Butuh stok >= 2 (tes memesan quantity 2).
    final inStock = products.items.where((p) => p.stock >= 2).toList();
    if (inStock.isEmpty) {
      markTestSkipped('tidak ada produk stok >= 2 di DB lokal');
    }
    final product = inStock.first;
    late final Order order;
    try {
      order = await api.guestCheckout(
        items: [GuestCheckoutItem(productId: product.id, quantity: 2)],
        customerName: 'Tamu Tes Takeaway',
        customerPhone: '081234567890',
        orderType: 'takeaway',
        paymentMethod: 'va',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        markTestSkipped('endpoint guest-checkout belum live (404)');
      }
      rethrow;
    }
    expect(order.status, 'pending');
    expect(order.payment, isNotNull);
    // VA tidak punya QR string (string kosong), tapi payment_url ada.
    expect(order.payment!.paymentUrl, contains('/mock-pay/'));
    final tracked = await api.trackOrder(order.orderNumber);
    expect(tracked.orderNumber, order.orderNumber);
  });

  test('guest checkout delivery kena ongkir 10000', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    final products = await api.listProducts(limit: 20);
    // Produk termurah agar total < 500rb (ongkir tidak gratis).
    final cheapest = products.items.reduce(
      (a, b) => a.price <= b.price ? a : b,
    );
    expect(cheapest.price, lessThan(500000));
    late final Order order;
    try {
      order = await api.guestCheckout(
        items: [GuestCheckoutItem(productId: cheapest.id, quantity: 1)],
        customerName: 'Tamu Tes Delivery',
        customerPhone: '081234567890',
        orderType: 'delivery',
        deliveryAddress: {
          'street': 'Jl. Tes No. 1',
          'city': 'Yogyakarta',
          'province': 'DIY',
          'postal_code': '55165',
        },
        paymentMethod: 'qris',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        markTestSkipped('endpoint guest-checkout belum live (404)');
      }
      rethrow;
    }
    expect(order.status, 'pending');
    expect(order.shippingCost, 10000);
    expect(order.total, order.subtotal + 10000);
  });

  test('LocalCartItem JSON round-trip (keranjang lokal tamu)', () {
    const item = LocalCartItem(
      productId: 'prod-1',
      name: 'Nasi Goreng Slaras',
      price: 25000,
      imageUrl: '/uploads/x.jpg',
      quantity: 2,
      notes: 'less sugar',
    );
    expect(item.subtotal, 50000);
    final restored = LocalCartItem.fromJson(item.toJson());
    expect(restored.productId, item.productId);
    expect(restored.name, item.name);
    expect(restored.price, item.price);
    expect(restored.quantity, item.quantity);
    expect(restored.notes, item.notes);
    expect(restored.subtotal, 50000);
    expect(restored.copyWith(quantity: 3).subtotal, 75000);
  });

  test('GuestOrdersState simpan + muat nomor order', () async {
    final state = GuestOrdersState();
    await state.load();
    await state.add('ORD-TEST-001');
    await state.add('ORD-TEST-002');
    expect(
      state.orders.map((e) => e.orderNumber),
      ['ORD-TEST-002', 'ORD-TEST-001'],
    );
    // Muat ulang dari penyimpanan (instans baru).
    final reloaded = GuestOrdersState();
    await reloaded.load();
    expect(
      reloaded.orders.map((e) => e.orderNumber),
      contains('ORD-TEST-001'),
    );
    await state.remove('ORD-TEST-001');
    expect(
      state.orders.map((e) => e.orderNumber),
      isNot(contains('ORD-TEST-001')),
    );
  });

  test('base URL guest mengikuti dart-define', () {
    const defined = String.fromEnvironment('API_BASE_URL');
    expect(
      AppConfig.apiBaseUrl,
      defined.isEmpty
          ? 'https://api.alikmakanmie.my.id/api/v1'
          : defined,
    );
  });
}
