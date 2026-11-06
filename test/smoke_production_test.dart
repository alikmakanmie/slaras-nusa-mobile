import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/main.dart';
import 'package:slaras_nusa_foodlab/state.dart';

/// Smoke test: boot aplikasi STAFF ASLI (pohon provider persis main()).
/// Tanpa sesi tersimpan, splash harus berujung di layar Login staf
/// (ADMIN & SUPERADMIN PORTAL) — tanpa FlutterError dan tanpa panggilan
/// jaringan (tidak ada token -> tidak ada API call).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('boot staf: splash -> layar login staf, tanpa error',
      (tester) async {
    final errors = <Object>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception);
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    // Pohon provider persis main(): SlarasStaffApp.
    final themeState = await ThemeState.load();
    final api = ApiClient();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<ThemeState>.value(value: themeState),
          ChangeNotifierProvider<AuthState>(create: (_) => AuthState(api)),
        ],
        child: const SlarasStaffApp(),
      ),
    );
    // Splash 900ms + init (tanpa token) -> LoginScreen.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(errors, isEmpty,
        reason: 'tidak boleh ada FlutterError saat boot: $errors');
    expect(find.text('ADMIN & SUPERADMIN PORTAL'), findsOneWidget);
    expect(find.text('LOGIN SEBAGAI ADMIN TOKO'), findsOneWidget);
    expect(find.text('LOGIN SEBAGAI SUPERADMIN'), findsOneWidget);
    // Tidak ada lagi alur pelanggan di aplikasi staf.
    expect(find.text('MASUK UNTUK MEMESAN'), findsNothing);
    expect(find.text('BUAT AKUN BARU'), findsNothing);
  });
}
