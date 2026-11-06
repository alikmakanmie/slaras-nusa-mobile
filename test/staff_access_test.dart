import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';
import 'package:slaras_nusa_foodlab/screens/home_shell.dart';
import 'package:slaras_nusa_foodlab/state.dart';

/// Akses staf: akun customer DITOLAK, tab USER hanya untuk superadmin.
/// Semua tes memakai MockClient (tanpa jaringan).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Map<String, dynamic> userJson(String role) => {
        'id': 'u-$role',
        'name': role == 'customer' ? 'Customer Tes' : 'Staf Tes',
        'email': '$role@slaras.local',
        'phone': '',
        'role': role,
        'is_active': true,
      };

  MockClient loginMock(String role) => MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login') || path.endsWith('/users/me')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'access_token': 'tok-akses',
                'refresh_token': 'tok-refresh',
                'user': userJson(role),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/auth/logout')) {
          return http.Response(
            jsonEncode({'success': true, 'data': {}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'success': false, 'error': 'tidak ditemukan'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

  test('login customer DITOLAK + token dibersihkan', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(httpClient: loginMock('customer'));
    addTearDown(api.dispose);
    await api.init();
    final auth = AuthState(api);
    expect(
      () => auth.login('customer@slaras.local', 'Customer123!'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          AuthState.accessDeniedMessage,
        ),
      ),
    );
    expect(auth.user, isNull);
    expect(api.hasToken, isFalse);
  });

  test('sesi customer tersimpan DITOLAK saat init', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'tok-lama',
      'refresh_token': 'tok-refresh-lama',
    });
    final api = ApiClient(httpClient: loginMock('customer'));
    addTearDown(api.dispose);
    final auth = AuthState(api);
    await auth.init();
    expect(auth.user, isNull);
    expect(api.hasToken, isFalse);
  });

  test('login admin & superadmin diterima', () async {
    SharedPreferences.setMockInitialValues({});
    final apiAdmin = ApiClient(httpClient: loginMock('admin'));
    addTearDown(apiAdmin.dispose);
    await apiAdmin.init();
    final authAdmin = AuthState(apiAdmin);
    await authAdmin.login('admin@slaras.local', 'Admin123!');
    expect(authAdmin.user?.role, 'admin');
    expect(authAdmin.isSuperAdmin, isFalse);

    SharedPreferences.setMockInitialValues({});
    final apiSuper = ApiClient(httpClient: loginMock('superadmin'));
    addTearDown(apiSuper.dispose);
    await apiSuper.init();
    final authSuper = AuthState(apiSuper);
    await authSuper.login('superadmin@slaras.local', 'SuperAdmin123!');
    expect(authSuper.user?.role, 'superadmin');
    expect(authSuper.isSuperAdmin, isTrue);
  });

  testWidgets('tab USER hanya muncul untuk superadmin', (tester) async {
    Future<void> pumpShell(String role) async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(httpClient: loginMock(role));
      addTearDown(api.dispose);
      await api.init();
      final auth = AuthState(api);
      await auth.login('$role@slaras.local', 'Password123!');
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<ApiClient>.value(value: api),
              ChangeNotifierProvider<AuthState>.value(value: auth),
            ],
            child: const HomeShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpShell('superadmin');
    expect(find.text('USER'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);

    await pumpShell('admin');
    expect(find.text('USER'), findsNothing);
    expect(find.text('MENU'), findsOneWidget);
  });
}
