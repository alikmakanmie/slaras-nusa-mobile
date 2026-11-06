import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/models.dart';
import 'package:slaras_nusa_foodlab/screens/floating_cart_bar.dart';
import 'package:slaras_nusa_foodlab/state.dart';

/// Tes Dashboard Profit admin + Floating Cart Bar.
///
/// Jalankan dengan API lokal menyala:
///   flutter test --dart-define API_BASE_URL=http://localhost:8080/api/v1
/// Tes live dilewati (markTestSkipped) bila endpoint profit belum live (404).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test memblokir HttpClient nyata secara default; tes integrasi
  // ini memang memanggil API lokal sungguhan, jadi kembalikan ke default.
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  const canned = {
    'period': 'today',
    'start_date': '2026-11-06',
    'end_date': '2026-11-06',
    'summary': {
      'gross_revenue': 1860000,
      'total_cogs': 1086000,
      'net_profit': 774000,
      'profit_margin_percent': 41.61,
      'total_paid_orders': 12,
      'average_order_value': 155000,
      'pending_or_cancelled_count': 20,
    },
    'daily_series': [
      {
        'date': '2026-11-06',
        'revenue': 1860000,
        'profit': 774000,
        'orders_count': 12,
      },
    ],
    'by_order_type': [
      {'order_type': 'dine_in', 'revenue': 533000, 'orders_count': 3},
      {'order_type': 'takeaway', 'revenue': 513000, 'orders_count': 4},
    ],
    'by_payment_method': [
      {'payment_method': 'qris', 'revenue': 1860000, 'orders_count': 12},
    ],
    'top_products': [
      {
        'product_id': 'p1',
        'product_name': 'Paket Nasi Box Slaras (isi 10)',
        'quantity_sold': 7,
        'revenue': 1750000,
        'profit': 700000,
      },
    ],
    'recent_transactions': [
      {
        'order_number': 'ORD-20261106-EJOHFQ',
        'customer_name': 'Alik',
        'order_type': 'delivery',
        'table_number': '',
        'status': 'paid',
        'total': 17000,
        'processed_by_name': 'Barista Slaras',
        'created_at': '2026-11-06T04:24:29.02670267+07:00',
      },
    ],
  };

  test('ProfitAnalytics.fromJson memetakan seluruh kontrak', () {
    final data = ProfitAnalytics.fromJson(canned);
    expect(data.period, 'today');
    expect(data.summary.grossRevenue, 1860000);
    expect(data.summary.totalCogs, 1086000);
    expect(data.summary.netProfit, 774000);
    expect(data.summary.profitMarginPercent, closeTo(41.61, 0.01));
    expect(data.summary.totalPaidOrders, 12);
    expect(data.summary.averageOrderValue, 155000);
    expect(data.summary.pendingOrCancelledCount, 20);
    expect(data.dailySeries.length, 1);
    expect(data.dailySeries.first.revenue, 1860000);
    expect(data.byOrderType.length, 2);
    expect(data.byOrderType.first.orderType, 'dine_in');
    expect(data.byPaymentMethod.first.paymentMethod, 'qris');
    expect(data.topProducts.first.productName, contains('Nasi Box'));
    expect(data.topProducts.first.profit, 700000);
    expect(data.recentTransactions.first.orderNumber, 'ORD-20261106-EJOHFQ');
    expect(data.recentTransactions.first.status, 'paid');
    expect(data.recentTransactions.first.processedByName, 'Barista Slaras');
    // Transaksi tanpa processed_by_name -> string kosong (UI menyembunyikan).
    final bare = RecentTransaction.fromJson({
      'order_number': 'ORD-X',
      'customer_name': 'Tamu',
      'status': 'pending',
      'total': 7000,
    });
    expect(bare.processedByName, '');
  });

  test('Product cost_price dibaca & dikirim (round-trip)', () {
    final p = Product.fromJson({
      'id': 'p1',
      'category_id': 'c1',
      'name': 'Nasi Goreng Slaras',
      'slug': 'nasi-goreng-slaras',
      'description': '',
      'price': 25000,
      'cost_price': 15000,
      'stock': 10,
      'sku': 'SNF-NAS-001',
      'image_url': '',
      'weight_gram': 300,
      'is_active': true,
    });
    expect(p.costPrice, 15000);
    expect(p.toRequestJson()['cost_price'], 15000);
    // Produk lama tanpa cost_price -> default 0 (tidak crash).
    final legacy = Product.fromJson({
      'id': 'p2',
      'name': 'Es Teh',
      'price': 6000,
    });
    expect(legacy.costPrice, 0);
  });

  test('admin profit live: today + 7d', () async {
    final api = ApiClient();
    addTearDown(api.dispose);
    await api.login('admin@ecommerce.local', 'Admin123!');
    late final ProfitAnalytics today;
    try {
      today = await api.getProfitAnalytics(period: 'today');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        markTestSkipped('endpoint admin/analytics/profit belum live (404)');
      }
      rethrow;
    }
    expect(today.summary.grossRevenue, greaterThanOrEqualTo(0));
    expect(today.summary.netProfit, greaterThanOrEqualTo(0));
    expect(today.dailySeries, isNotEmpty);
    final week = await api.getProfitAnalytics(period: '7d');
    expect(week.period, '7d');
    expect(week.dailySeries.length, greaterThanOrEqualTo(1));
    await api.logout();
  });

  testWidgets('FloatingCartBar muncul saat keranjang berisi item',
      (tester) async {
    final api = ApiClient();
    addTearDown(api.dispose);
    final cart = CartState(api);
    final auth = AuthState(api);
    await cart.init(loggedIn: false);

    const productA = Product(
      id: 'p-a',
      categoryId: 'c1',
      category: null,
      name: 'Nasi Goreng Slaras',
      slug: 'nasi-goreng-slaras',
      description: '',
      price: 25000,
      stock: 10,
      sku: 'SNF-NAS-001',
      imageUrl: '',
      weightGram: 300,
      isActive: true,
    );
    const productB = Product(
      id: 'p-b',
      categoryId: 'c1',
      category: null,
      name: 'Es Teh Melati',
      slug: 'es-teh-melati',
      description: '',
      price: 6000,
      stock: 10,
      sku: 'SNF-TEH-001',
      imageUrl: '',
      weightGram: 100,
      isActive: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<CartState>.value(value: cart),
              ChangeNotifierProvider<AuthState>.value(value: auth),
            ],
            child: const Stack(
              children: [
                SizedBox.expand(),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: FloatingCartBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Keranjang kosong -> bar tidak tampil.
    expect(find.text('CHECKOUT SEKARANG →'), findsNothing);

    // Tambah 2 item -> bar muncul dengan badge + total.
    await cart.addLocal(productA, 1);
    await cart.addLocal(productB, 2);
    await tester.pump();
    expect(find.text('[ 3 ITEM ]'), findsOneWidget);
    expect(find.text('CHECKOUT SEKARANG →'), findsOneWidget);
    expect(find.text('LIHAT / EDIT'), findsOneWidget);
    // Total: 25000 + 2x6000 = 37000.
    expect(find.text('Rp37.000'), findsOneWidget);
    // Nama menu singkat tampil.
    expect(find.textContaining('Nasi Goreng Slaras'), findsOneWidget);

    // Kosongkan -> bar hilang lagi.
    await cart.clearLocalCart();
    await tester.pump();
    expect(find.text('CHECKOUT SEKARANG →'), findsNothing);
  });
}
