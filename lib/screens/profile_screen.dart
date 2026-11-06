import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'addresses_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_profit_screen.dart';
import 'home_shell.dart';

/// Profil pengguna: edit nama/HP, toggle dark mode, alamat, admin, logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEdit() {
    final user = context.read<AuthState>().user;
    if (user == null) return;
    _nameController.text = user.name;
    _phoneController.text = user.phone;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().length < 2) {
      showSnack(context, 'Nama minimal 2 karakter', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthState>().updateProfile(
            _nameController.text.trim(),
            _phoneController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _editing = false);
      showSnack(context, 'Profil diperbarui');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KELUAR?'),
        content: const Text('Kamu akan keluar dari akun ini.'),
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
    if (confirm != true) return;
    if (!mounted) return;
    await context.read<AuthState>().logout();
    if (!mounted) return;
    final cart = context.read<CartState>();
    cart.clearLocal();
    // Kembali ke mode keranjang lokal tamu + katalog (tanpa paksa login).
    cart.setLoggedIn(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final themeState = context.watch<ThemeState>();
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('PROFIL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalCard(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.pureBlack,
                      border: Border.all(
                        color: AppTheme.borderOf(context),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.name.isEmpty
                          ? '?'
                          : user.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: AppTheme.mutedOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(
                          status: user.isSuperAdmin
                              ? 'SUPERADMIN'
                              : user.isAdmin
                                  ? 'ADMIN'
                                  : 'CUSTOMER',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_editing) ...[
              BrutalTextField(
                controller: _nameController,
                label: 'Nama Lengkap',
              ),
              const SizedBox(height: 12),
              BrutalTextField(
                controller: _phoneController,
                label: 'No. HP',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BrutalButton(
                      label: 'SIMPAN',
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrutalButton(
                      label: 'BATAL',
                      primary: false,
                      onPressed: () => setState(() => _editing = false),
                    ),
                  ),
                ],
              ),
            ] else ...[
              BrutalCard(
                child: Column(
                  children: [
                    _infoRow('NAMA', user.name),
                    const SizedBox(height: 8),
                    _infoRow('EMAIL', user.email),
                    const SizedBox(height: 8),
                    _infoRow(
                      'NO. HP',
                      user.phone.isEmpty ? '-' : user.phone,
                    ),
                    const SizedBox(height: 8),
                    _infoRow('PERAN', user.role.toUpperCase()),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BrutalButton(
                label: 'EDIT PROFIL',
                icon: Icons.edit,
                primary: false,
                onPressed: _startEdit,
              ),
            ],
            const SizedBox(height: 16),
            BrutalCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dark_mode, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'MODE GELAP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 14),
            BrutalButton(
              label: 'ALAMAT SAYA',
              icon: Icons.location_on,
              primary: false,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddressesScreen(),
                  ),
                );
              },
            ),
            if (user.isAdmin) ...[
              const SizedBox(height: 20),
              const SectionTitle(title: 'Mode Admin'),
              const SizedBox(height: 10),
              BrutalButton(
                label: 'KELOLA PRODUK',
                icon: Icons.inventory_2,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminProductsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              BrutalButton(
                label: 'KELOLA KATEGORI',
                icon: Icons.category,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminCategoriesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              BrutalButton(
                label: 'KELOLA PESANAN',
                icon: Icons.receipt_long,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminOrdersScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              BrutalButton(
                label: 'DASHBOARD PROFIT',
                icon: Icons.bar_chart,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminProfitScreen(),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            BrutalButton(
              label: 'KELUAR',
              icon: Icons.logout,
              primary: false,
              onPressed: _logout,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'SLARAS NUSA FOODLAB v1.0.0',
                style: TextStyle(
                  color: AppTheme.mutedOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedOf(context),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
