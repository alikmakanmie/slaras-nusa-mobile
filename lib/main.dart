import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'screens/splash_screen.dart';
import 'state.dart';
import 'theme.dart';

/// SLARAS NUSA STAFF — aplikasi backoffice khusus Admin & Superadmin.
/// Pelanggan memesan lewat website (guest checkout); aplikasi ini TIDAK
/// punya katalog belanja, keranjang, atau guest checkout.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeState = await ThemeState.load();
  final api = ApiClient();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<ThemeState>.value(value: themeState),
        ChangeNotifierProvider<AuthState>(
          create: (_) => AuthState(api),
        ),
      ],
      child: const SlarasStaffApp(),
    ),
  );
}

class SlarasStaffApp extends StatelessWidget {
  const SlarasStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeState>().isDark;
    return MaterialApp(
      title: 'SLARAS NUSA STAFF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
