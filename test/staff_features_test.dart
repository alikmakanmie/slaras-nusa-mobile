import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/models.dart';
import 'package:slaras_nusa_foodlab/staff_helpers.dart';

/// Fitur staf Bagian 3: QR meja, varian/add-on, voucher, toggle
/// availability, struk. Semua tes memakai MockClient / fungsi murni
/// (tanpa jaringan).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('QR meja', () {
    test('tableQrUrl memformat nomor 2 digit', () {
      expect(tableQrUrl(1), 'https://alikmakanmie.my.id/?table=01');
      expect(tableQrUrl(5), 'https://alikmakanmie.my.id/?table=05');
      expect(tableQrUrl(20), 'https://alikmakanmie.my.id/?table=20');
    });

    test('allTableQrUrls: 20 URL unik Meja 01-20', () {
      final urls = allTableQrUrls();
      expect(urls.length, 20);
      expect(urls.toSet().length, 20);
      expect(urls.first, contains('table=01'));
      expect(urls.last, contains('table=20'));
    });
  });

  group('Varian / add-on bawaan', () {
    test('defaultModifiers: 4 grup, harga add-on sesuai kontrak', () {
      final groups = defaultModifiers();
      expect(groups.length, 4);
      expect(groups.map((g) => g.name).toList(), [
        'Temperature',
        'Sugar Level',
        'Ice Level',
        'Add-Ons',
      ]);
      final addOns = groups.last.options;
      final shot = addOns.firstWhere(
        (o) => o.name == 'Extra Espresso Shot',
      );
      expect(shot.priceDelta, 5000);
      expect(shot.costDelta, 2500);
      final oat = addOns.firstWhere((o) => o.name == 'Upgrade Oat Milk');
      expect(oat.priceDelta, 8000);
      expect(oat.costDelta, 4500);
    });

    test('Product parse modifiers_json string + is_available false', () {
      final p = Product.fromJson({
        'id': 'p1',
        'name': 'Kopi Susu',
        'price': 18000,
        'cost_price': 9000,
        'stock': 10,
        'is_active': true,
        'is_available': false,
        'modifiers_json': jsonEncode({
          'groups': [
            {
              'name': 'Sugar Level',
              'type': 'single',
              'options': [
                {'name': 'Less Sugar', 'price_delta': 0, 'cost_delta': 0},
              ],
            },
          ],
        }),
      });
      expect(p.isAvailable, isFalse);
      expect(p.modifiers.length, 1);
      expect(p.modifiers.first.options.first.name, 'Less Sugar');
      expect(p.costPrice, 9000);
    });

    test('Product lama tanpa field baru -> is_available true, modifiers kosong', () {
      final p = Product.fromJson({'id': 'p1', 'name': 'Tumbler', 'price': 1});
      expect(p.isAvailable, isTrue);
      expect(p.modifiers, isEmpty);
    });

    test('toRequestJson menyertakan is_available + modifiers_json', () {
      final p = Product.fromJson({'id': 'p1', 'name': 'Kopi', 'price': 1})
          .copyWith(isAvailable: false, modifiers: defaultModifiers());
      final req = p.toRequestJson();
      expect(req['is_available'], isFalse);
      final decoded = jsonDecode(req['modifiers_json'] as String)
          as Map<String, dynamic>;
      expect((decoded['groups'] as List).length, 4);
    });
  });

  group('OrderItem & Order baru', () {
    test('OrderItem parse selected_modifiers + unit_price/unit_cost', () {
      final item = OrderItem.fromJson({
        'id': 'i1',
        'product_name': 'Kopi Susu',
        'price': 18000,
        'quantity': 2,
        'subtotal': 46000,
        'selected_modifiers': [
          {'name': 'Less Sugar', 'price_delta': 0, 'cost_delta': 0},
          {'name': 'Extra Espresso Shot', 'price_delta': 5000, 'cost_delta': 2500},
        ],
        'unit_price': 23000,
        'unit_cost': 11500,
      });
      expect(item.modifiersLabel, 'Less Sugar, Extra Espresso Shot');
      expect(item.unitPrice, 23000);
      expect(item.unitCost, 11500);
    });

    test('Order parse voucher_code + discount_amount', () {
      final order = Order.fromJson({
        'id': 'o1',
        'order_number': 'ORD-20261107-000001',
        'status': 'paid',
        'subtotal': 50000,
        'total': 40000,
        'voucher_code': 'SLARASHEMAT',
        'discount_amount': 10000,
        'items': [],
      });
      expect(order.voucherCode, 'SLARASHEMAT');
      expect(order.discountAmount, 10000);
    });
  });

  group('Voucher model', () {
    test('fromJson + label diskon', () {
      final v = Voucher.fromJson({
        'id': 'v1',
        'code': 'slarashemat',
        'discount_type': 'percentage',
        'discount_value': 20,
        'min_order_amount': 30000,
        'max_discount': 15000,
        'quota': 100,
        'used_count': 3,
        'is_active': true,
      });
      expect(v.code, 'SLARASHEMAT');
      expect(v.discountLabel, 'DISKON 20%');
      expect(v.quotaLabel, '3/100 dipakai');
    });
  });

  group('ApiClient: toggle availability', () {
    test('PATCH ke /products/:id/availability dengan body benar', () async {
      var seenMethod = '';
      var seenPath = '';
      var seenBody = '';
      final api = ApiClient(
        httpClient: MockClient((request) async {
          seenMethod = request.method;
          seenPath = request.url.path;
          seenBody = request.body;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'p1', 'is_available': false},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.dispose);
      final result = await api.toggleProductAvailability('p1', false);
      expect(result, isFalse);
      expect(seenMethod, 'PATCH');
      expect(seenPath, endsWith('/products/p1/availability'));
      expect(
        jsonDecode(seenBody),
        {'is_available': false},
      );
    });

    test('toggle gagal (404) -> ApiException', () async {
      final api = ApiClient(
        httpClient: MockClient((_) async => http.Response(
              jsonEncode({'success': false, 'error': 'produk tidak ditemukan'}),
              404,
              headers: {'content-type': 'application/json'},
            )),
      );
      addTearDown(api.dispose);
      expect(
        () => api.toggleProductAvailability('nope', false),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ApiClient: voucher CRUD', () {
    test('listVouchers GET /admin/vouchers', () async {
      final api = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('/admin/vouchers'));
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'v1',
                  'code': 'KOPIPAGI',
                  'discount_type': 'fixed',
                  'discount_value': 10000,
                  'min_order_amount': 25000,
                  'is_active': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.dispose);
      final list = await api.listVouchers();
      expect(list.length, 1);
      expect(list.first.code, 'KOPIPAGI');
      expect(list.first.discountLabel, 'POTONGAN Rp10.000');
    });
  });

  group('Struk thermal', () {
    test('receiptText memuat nomor order, varian, voucher, total', () {
      final order = Order.fromJson({
        'id': 'o1',
        'order_number': 'ORD-20261107-000001',
        'status': 'paid',
        'subtotal': 46000,
        'total': 36000,
        'order_type': 'dine_in',
        'table_number': '05',
        'shipping_name': 'Budi',
        'voucher_code': 'SLARASHEMAT',
        'discount_amount': 10000,
        'processed_by_name': 'Admin',
        'items': [
          {
            'product_name': 'Kopi Susu',
            'price': 18000,
            'quantity': 2,
            'subtotal': 46000,
            'selected_modifiers': [
              {'name': 'Less Sugar'},
              {'name': 'Extra Espresso Shot'},
            ],
          },
        ],
      });
      final text = receiptText(order);
      expect(text, contains('ORD-20261107-000001'));
      expect(text, contains('MEJA 05'));
      expect(text, contains('Less Sugar, Extra Espresso Shot'));
      expect(text, contains('SLARASHEMAT'));
      expect(text, contains('Rp36.000'));
      expect(text, contains('Diproses oleh: Admin'));
    });
  });
}
