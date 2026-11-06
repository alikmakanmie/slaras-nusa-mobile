import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'screens/splash_screen.dart';
import 'state.dart';
import 'theme.dart';

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
        ChangeNotifierProvider<CartState>(
          create: (_) => CartState(api),
        ),
        ChangeNotifierProvider<AddressState>(
          create: (_) => AddressState(api),
        ),
        ChangeNotifierProvider<GuestOrdersState>(
          create: (_) => GuestOrdersState(),
        ),
      ],
      child: const SlarasApp(),
    ),
  );
}

class SlarasApp extends StatelessWidget {
  const SlarasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeState>().isDark;
    return MaterialApp(
      title: 'SLARAS NUSA FOODLAB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
