import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';

/// Layar login STAFF — SLARAS NUSA ADMIN & SUPERADMIN PORTAL.
///
/// - Login wajib: tidak ada mode tamu/pelanggan di aplikasi ini.
/// - Akun customer DITOLAK (AuthState.login melempar ApiException +
///   membersihkan token).
/// - Semua error jaringan ditangkap: TIDAK PERNAH ada Unhandled Exception.
///   ApiClient mengubah SocketException/ClientException/timeout menjadi
///   ApiException berpesan ramah; _submit juga menangkap Exception umum.
/// - Tombol demo sekali tap: isi + langsung login sebagai Admin/Superadmin.
/// - Ikon server (pojok kanan atas): ganti Server URL manual
///   (domain utama / IP VPS cadangan / URL sendiri).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    showSnack(context, message, isError: true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final auth = context.read<AuthState>();
    try {
      await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      // Jaring pengaman terakhir: error apa pun TIDAK BOLEH jadi
      // Unhandled Exception (kasus login_screen.dart:38, 6 Nov 2026).
      _showError(
        'Tidak bisa terhubung ke server. Periksa koneksi internet, '
        'lalu coba lagi.',
      );
    }
  }

  Future<void> _demoLogin(String email, String password) async {
    _emailController.text = email;
    _passwordController.text = password;
    setState(() => _error = null);
    await _submit();
  }

  Future<void> _openServerSettings() async {
    final api = context.read<ApiClient>();
    final controller = TextEditingController(
      text: api.manualOverride ?? '',
    );
    final saved = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('PENGATURAN SERVER'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server aktif: ${api.baseUrl}'
                  '${api.isUsingFallback ? ' (FALLBACK IP VPS)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kosongkan untuk kembali ke server utama (domain). '
                  'Isi URL lengkap dengan http(s):// dan akhiran /api/v1.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'SERVER URL',
                    hintText: 'https://api.alikmakanmie.my.id/api/v1',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pop('__PRIMARY__'),
                        child: const Text('DOMAIN'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pop('__FALLBACK__'),
                        child: const Text('IP VPS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('BATAL'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('SIMPAN'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    if (saved == '__PRIMARY__') {
      await api.setServerOverride(null);
    } else if (saved == '__FALLBACK__') {
      await api.setServerOverride(api.fallbackBaseUrl);
    } else {
      await api.setServerOverride(saved.isEmpty ? null : saved);
    }
    if (!mounted) return;
    showSnack(context, 'Server: ${api.baseUrl}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthState>().busy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                      ),
                      tooltip: 'Ganti tema',
                      onPressed: () =>
                          context.read<ThemeState>().toggle(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.dns_outlined),
                      tooltip: 'Pengaturan server',
                      onPressed: busy ? null : _openServerSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'SLARAS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                    letterSpacing: 5,
                  ),
                ),
                const Text(
                  'NUSA STAFF',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ADMIN & SUPERADMIN PORTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Khusus staf SLARAS NUSA FOODLAB. Pelanggan memesan '
                  'lewat website.',
                  style: TextStyle(
                    color: AppTheme.mutedOf(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),
                BrutalTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'nama@email.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                BrutalTextField(
                  controller: _passwordController,
                  label: 'Kata Sandi',
                  hint: 'Minimal 8 karakter',
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Kata sandi wajib diisi';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                BrutalButton(
                  label: 'MASUK',
                  icon: Icons.login,
                  loading: busy,
                  onPressed: busy ? null : _submit,
                ),
                const SizedBox(height: 28),
                const Divider(thickness: 2),
                const SizedBox(height: 12),
                const Text(
                  'LOGIN CEPAT STAF (SATU KETUKAN)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                BrutalButton(
                  label: 'LOGIN SEBAGAI ADMIN TOKO',
                  primary: false,
                  onPressed: busy
                      ? null
                      : () => _demoLogin(
                            'admin@ecommerce.local',
                            'Admin123!',
                          ),
                ),
                const SizedBox(height: 12),
                BrutalButton(
                  label: 'LOGIN SEBAGAI SUPERADMIN',
                  primary: false,
                  onPressed: busy
                      ? null
                      : () => _demoLogin(
                            'superadmin@slaras.local',
                            'SuperAdmin123!',
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
