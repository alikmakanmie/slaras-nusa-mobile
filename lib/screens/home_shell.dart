import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_profit_screen.dart';
import 'admin_users_screen.dart';
import 'login_screen.dart';

/// Shell utama APLIKASI STAFF: bottom navigation khusus admin/superadmin.
///
/// - Tab 1: DASHBOARD PROFIT
/// - Tab 2: PESANAN MASUK (POS / antrean dapur)
/// - Tab 3: KELOLA MENU & STOK
/// - Tab 4: KELOLA USER — hanya bila role == superadmin (disembunyikan
///   untuk admin biasa).
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KELUAR?'),
        content: const Text('Keluar dari portal staf SLARAS NUSA?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AuthState>().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final isSuperAdmin = context.watch<AuthState>().isSuperAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final labels = isSuperAdmin
        ? const ['DASHBOARD', 'PESANAN', 'MENU', 'USER']
        : const ['DASHBOARD', 'PESANAN', 'MENU'];
    final titles = isSuperAdmin
        ? const [
            'DASHBOARD PROFIT',
            'PESANAN MASUK',
            'KELOLA MENU & STOK',
            'KELOLA USER',
          ]
        : const [
            'DASHBOARD PROFIT',
            'PESANAN MASUK',
            'KELOLA MENU & STOK',
          ];
    final icons = isSuperAdmin
        ? const [
            Icons.bar_chart,
            Icons.receipt_long,
            Icons.restaurant_menu,
            Icons.group,
          ]
        : const [
            Icons.bar_chart,
            Icons.receipt_long,
            Icons.restaurant_menu,
          ];
    final tabs = isSuperAdmin
        ? const [
            AdminProfitScreen(),
            AdminOrdersScreen(),
            AdminProductsScreen(),
            AdminUsersScreen(),
          ]
        : const [
            AdminProfitScreen(),
            AdminOrdersScreen(),
            AdminProductsScreen(),
          ];
    final safeIndex = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[safeIndex]),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSuperAdmin
                        ? AppTheme.badRed
                        : (isDark ? Colors.white : AppTheme.pureBlack),
                    border: Border.all(
                      color: AppTheme.pureBlack,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    user.roleLabel,
                    style: TextStyle(
                      color: isSuperAdmin
                          ? Colors.white
                          : (isDark ? AppTheme.pureBlack : Colors.white),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: tabs),
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
          currentIndex: safeIndex,
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
          items: List.generate(labels.length, (i) {
            return BottomNavigationBarItem(
              icon: Icon(icons[i], size: 24),
              label: labels[i],
            );
          }),
        ),
      ),
    );
  }
}
