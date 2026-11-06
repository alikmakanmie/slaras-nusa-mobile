import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'guest_profile_screen.dart';
import 'guest_track_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

/// Shell utama: bottom navigation 4 tab.
/// Dipakai juga dari HomeScreen untuk lompat ke tab keranjang.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static HomeShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeShellState>();
  }

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  void goToTab(int index) {
    setState(() => _index = index);
  }

  List<Widget> _tabs(bool loggedIn) => [
        const HomeScreen(),
        const CartScreen(),
        // Tamu: lacak + struk via nomor order (tanpa login).
        // Member: riwayat order dari API.
        loggedIn ? const OrdersScreen() : const GuestTrackScreen(),
        // Tamu: layar login/daftar. Member: profil + alamat + admin.
        loggedIn ? const ProfileScreen() : const GuestProfileScreen(),
      ];

  static const _labels = ['BERANDA', 'KERANJANG', 'PESANAN', 'PROFIL'];
  static const _icons = [
    Icons.home,
    Icons.shopping_cart,
    Icons.receipt_long,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartState>().totalItems;
    final loggedIn = context.watch<AuthState>().isLoggedIn;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs(loggedIn)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: Border(
            top: BorderSide(
              color: AppTheme.borderOf(context),
              width: 2,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: goToTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: isDark ? Colors.white : AppTheme.pureBlack,
          unselectedItemColor: AppTheme.mutedOf(context),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1,
          ),
          items: List.generate(_labels.length, (i) {
            final icon = Icon(_icons[i], size: 24);
            return BottomNavigationBarItem(
              icon: i == 1 && cartCount > 0
                  ? Badge(
                      label: Text('$cartCount'),
                      backgroundColor: AppTheme.badRed,
                      child: icon,
                    )
                  : icon,
              label: _labels[i],
            );
          }),
        ),
      ),
    );
  }
}
