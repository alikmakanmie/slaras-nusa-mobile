import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets.dart';
import 'login_screen.dart';

/// Onboarding 3 halaman dengan tema brutal.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.restaurant_menu,
      title: 'SELAMAT DATANG DI SLARAS NUSA FOODLAB',
      body:
          'Kuliner rumahan khas Slaras: nasi goreng, ayam geprek, rendang, sampai hampers acara. Dimasak segar setiap hari dari dapur Foodlab.',
    ),
    (
      icon: Icons.shopping_basket,
      title: 'PESAN CEPAT, BAYAR MUDAH',
      body:
          'Pilih menu favorit, atur keranjang, checkout dengan QRIS atau Virtual Account. Semua pesanan tercatat rapi dan bisa dilacak.',
    ),
    (
      icon: Icons.local_shipping,
      title: 'LACAK PESANAN REAL-TIME',
      body:
          'Pantau status pesananmu: dibayar, diproses, dikirim, sampai selesai. Butuh bantuan? Hubungi kami langsung dari aplikasi.',
    ),
  ];

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SLARAS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 3,
                    ),
                  ),
                  GestureDetector(
                    onTap: _finish,
                    child: const Text(
                      'LEWATI',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.5,
                        decoration: TextDecoration.underline,
                        decorationThickness: 2,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final p = _pages[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: AppTheme.brutalCard(context, size: 6),
                          padding: const EdgeInsets.all(28),
                          child: Icon(p.icon, size: 72),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 1.2,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.mutedOf(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return Container(
                    width: _page == i ? 28 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppTheme.borderOf(context)
                          : AppTheme.mutedOf(context).withValues(alpha: 0.35),
                      border: Border.all(
                        color: AppTheme.borderOf(context),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              BrutalButton(
                label: _page == _pages.length - 1
                    ? 'MULAI MEMESAN'
                    : 'LANJUT',
                icon: Icons.arrow_forward,
                onPressed: () {
                  if (_page == _pages.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
