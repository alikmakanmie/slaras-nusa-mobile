import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Tab Profil untuk tamu (belum login): ajakan login/daftar member,
/// plus jalan pintas lacak pesanan. Login member/admin/kasir tetap di sini.
class GuestProfileScreen extends StatelessWidget {
  const GuestProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeState>();
    return Scaffold(
      appBar: AppBar(title: const Text('PROFIL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MODE TAMU',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kamu sedang belanja sebagai tamu. Keranjang dan nomor order tersimpan di perangkat ini.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Login sebagai Member / Admin / Kasir untuk riwayat order tersimpan, alamat, dan kelola toko.',
                    style: TextStyle(
                      color: AppTheme.mutedOf(context),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BrutalButton(
              label: 'LOGIN MEMBER / ADMIN / KASIR',
              icon: Icons.login,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: 'DAFTAR MEMBER',
              icon: Icons.person_add,
              primary: false,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: 'LACAK PESANAN SAYA',
              icon: Icons.receipt_long,
              primary: false,
              onPressed: () => HomeShell.of(context)?.goToTab(2),
            ),
            const SizedBox(height: 18),
            BrutalCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MODE GELAP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Switch(
                    value: themeState.isDark,
                    onChanged: (_) => themeState.toggle(),
                    activeThumbColor: AppTheme.pureBlack,
                    activeTrackColor: AppTheme.mutedOf(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SLARAS NUSA FOODLAB v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedOf(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
