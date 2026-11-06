import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/main.dart';
import 'package:slaras_nusa_foodlab/state.dart';

/// Smoke test: boot aplikasi ASLI (pohon provider persis main()) melawan API
/// PRODUKSI dan pastikan katalog tampil tanpa exception.
///   flutter test test/smoke_production_test.dart \
///     --dart-define API_BASE_URL=https://api.alikmakanmie.my.id/api/v1
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({'onboarding_seen': true});

  testWidgets('boot produksi: splash -> katalog tampil, tanpa error',
      (tester) async {
    final errors = <Object>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception);
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    // Pohon provider persis main(): SlarasApp butuh ThemeState di atasnya.
    final themeState = await ThemeState.load();
    final api = ApiClient();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<ThemeState>.value(value: themeState),
          ChangeNotifierProvider<AuthState>(create: (_) => AuthState(api)),
          ChangeNotifierProvider<CartState>(create: (_) => CartState(api)),
          ChangeNotifierProvider<AddressState>(
              create: (_) => AddressState(api)),
          ChangeNotifierProvider<GuestOrdersState>(
              create: (_) => GuestOrdersState()),
        ],
        child: const SlarasApp(),
      ),
    );
    // Splash 900ms + init + load katalog dari API produksi.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Kopi Susu Slaras Aren').evaluate().isNotEmpty) break;
    }
    // pumpAndSettle sengaja TIDAK dipakai: CircularProgressIndicator /
    // animasi lain membuat frame tak pernah settle. Dump isi layar sebagai
    // diagnosis, lalu asersi.
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.isNotEmpty)
        .take(40)
        .toList();
    // ignore: avoid_print
    print('TEKS DI LAYAR: $texts');
    // ignore: avoid_print
    print('ERRORS: $errors');
    // ignore: avoid_print
    print(
        'KATALOG MUNCUL: ${find.text('Kopi Susu Slaras Aren').evaluate().isNotEmpty}');

    expect(errors, isEmpty,
        reason: 'tidak boleh ada FlutterError saat boot: $errors');
    expect(find.text('Kopi Susu Slaras Aren'), findsWidgets,
        reason: 'katalog produksi harus tampil');
  });
}
