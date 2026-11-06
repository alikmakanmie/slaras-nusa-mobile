import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// Splash: logo brutal + cek sesi tersimpan, lalu arahkan ke
/// Onboarding (baru pertama kali) / Katalog (HomeShell).
/// Login TIDAK dipaksa — tamu langsung bisa lihat katalog & pesan.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final auth = context.read<AuthState>();
    await auth.init();
    if (!mounted) return;
    // Keranjang lokal + daftar order tamu dimuat tanpa login;
    // bila sesi member tersimpan, keranjang beralih ke mode server.
    await context.read<CartState>().init(loggedIn: auth.isLoggedIn);
    if (!mounted) return;
    await context.read<GuestOrdersState>().load();
    if (!mounted) return;
    final seen = await OnboardingScreen.hasSeen();
    if (!mounted) return;
    // Tamu maupun member langsung ke katalog — login hanya di tab Profil.
    final Widget next =
        seen ? const HomeShell() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(6, 6),
                    blurRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: const Text(
                'SLARAS',
                style: TextStyle(
                  color: AppTheme.pureBlack,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'NUSA FOODLAB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'KULINER • F&B • HAMPERS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
