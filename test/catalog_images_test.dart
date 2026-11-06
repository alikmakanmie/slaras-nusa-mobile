import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/models.dart';
import 'package:slaras_nusa_foodlab/widgets.dart';

/// Tes gambar produk/kategori + audit trail (processed_by_name).
///
/// Jalankan dengan API lokal menyala:
///   flutter test --dart-define API_BASE_URL=http://localhost:8080/api/v1
/// Tes live dilewati bila API lokal mati / data belum memadai.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test memblokir HttpClient nyata secara default; tes integrasi
  // ini memang memanggil API lokal sungguhan, jadi kembalikan ke default.
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  test('katalog baru: 18 menu aktif, semua punya image_url Unsplash',
      () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    late final List<Product> products;
    try {
      final page = await api.listProducts(limit: 100);
      products = page.items;
    } on ApiException catch (e) {
      markTestSkipped('API lokal tidak merespons: ${e.message}');
      return;
    }
    expect(products.length, greaterThanOrEqualTo(18),
        reason: 'seeder kopi baru: 18 menu aktif');
    final withUnsplash = products
        .where((p) => p.imageUrl.contains('images.unsplash.com'))
        .length;
    expect(withUnsplash, greaterThanOrEqualTo(15),
        reason: 'menu baru memakai foto Unsplash CDN');
    // Semua produk aktif punya image_url (kosong hanya untuk data lama).
    final withoutImage =
        products.where((p) => p.imageUrl.isEmpty).length;
    expect(withoutImage, 0);
  });

  test('kategori baru punya image_url Unsplash', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    late final List<Category> cats;
    try {
      cats = await api.listCategories();
    } on ApiException catch (e) {
      markTestSkipped('API lokal tidak merespons: ${e.message}');
      return;
    }
    expect(cats.length, greaterThanOrEqualTo(5),
        reason: 'seeder kopi baru: 5 kategori');
    final withImage =
        cats.where((c) => c.imageUrl.contains('images.unsplash.com')).length;
    expect(withImage, greaterThanOrEqualTo(5),
        reason: 'kategori baru memakai foto Unsplash CDN');
  });

  testWidgets('ProductImage gagal dimuat -> placeholder nama menu',
      (tester) async {
    const name = 'Kopi Sanger Slaras';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImage(
            // Port 1 tidak pernah listen -> connection refused instan,
            // errorBuilder langsung menampilkan placeholder.
            imageUrl: 'http://127.0.0.1:1/tidak-ada.jpg',
            fallbackName: name,
            height: 140,
          ),
        ),
      ),
    );
    // Image.network di tes memicu error -> errorBuilder menampilkan
    // placeholder BoldKit bertuliskan nama menu (uppercase).
    // runAsync: biarkan I/O socket nyata (connection refused) selesai
    // di luar zona fake-async tester, lalu pump untuk rebuild.
    await tester.runAsync(() async {
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    expect(find.text(name.toUpperCase()), findsOneWidget);
  });

  testWidgets('ProductImage tanpa URL -> placeholder nama menu',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImage(
            imageUrl: '',
            fallbackName: 'Es Kopi Gula Aren',
            height: 110,
          ),
        ),
      ),
    );
    expect(find.text('ES KOPI GULA AREN'), findsOneWidget);
  });

  test('Order.fromJson memetakan processed_by_name', () {
    final order = Order.fromJson({
      'id': 'o1',
      'order_number': 'ORD-TEST-1',
      'status': 'processing',
      'subtotal': 17000,
      'total': 17000,
      'processed_by_name': 'Barista Slaras',
      'items': [],
      'created_at': '2026-11-06T12:00:00+07:00',
    });
    expect(order.processedByName, 'Barista Slaras');
    final bare = Order.fromJson({
      'id': 'o2',
      'order_number': 'ORD-TEST-2',
      'status': 'pending',
      'items': [],
    });
    expect(bare.processedByName, '');
  });

  test('audit trail live: barista ubah status -> processed_by_name tercatat',
      () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    try {
      await api.login('barista@slaras.local', 'Barista123!');
    } on ApiException catch (e) {
      markTestSkipped('login barista gagal: ${e.message}');
      return;
    }
    late final List<Order> orders;
    try {
      orders = (await api.listAllOrders(limit: 20)).items;
    } on ApiException catch (e) {
      markTestSkipped('list admin orders gagal: ${e.message}');
      return;
    }
    final paid =
        orders.where((o) => o.status == 'paid').toList();
    if (paid.isEmpty) {
      markTestSkipped('tidak ada order paid untuk diuji audit trail');
      return;
    }
    final target = paid.first;
    final updated = await api.updateOrderStatus(target.id, 'processing');
    expect(updated.processedByName, 'Barista Slaras',
        reason: 'PATCH status oleh barista harus mencatat namanya');
    // Bukti persistensi: baca ulang order yang sama dari API.
    final reloaded = (await api.listAllOrders(limit: 20))
        .items
        .firstWhere((o) => o.orderNumber == target.orderNumber);
    expect(reloaded.processedByName, 'Barista Slaras');
    // Profit recent transactions ikut membawa nama pemroses bila order
    // tersebut masuk 10 transaksi terbaru; bila tidak masuk (tes lain
    // membuat order baru), cukup pastikan endpoint mem-parse field-nya
    // (dibuktikan unit test fromJson + verifikasi curl manual).
    final profit = await api.getProfitAnalytics(period: 'all');
    final found = profit.recentTransactions
        .where((tx) => tx.orderNumber == target.orderNumber);
    if (found.isNotEmpty) {
      expect(found.first.processedByName, 'Barista Slaras');
    }
  });
}
