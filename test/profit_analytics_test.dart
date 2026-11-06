import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/models.dart';

/// Tes Dashboard Profit admin (model + endpoint live).
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
    await api.init();
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
}
