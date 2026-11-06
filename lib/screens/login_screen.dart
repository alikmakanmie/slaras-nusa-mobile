import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../widgets.dart';
import 'home_shell.dart';
import 'register_screen.dart';

/// Layar login. Ada tombol isi cepat akun demo (customer / admin)
/// untuk pengujian.
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
      // Beralih ke mode keranjang server + dorong isi keranjang lokal tamu.
      final cart = context.read<CartState>();
      cart.setLoggedIn(true);
      await cart.syncLocalToServer();
      if (!mounted) return;
      await cart.refresh();
      if (!mounted) return;
      await context.read<AddressState>().refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _fillDemo(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthState>().busy;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'SLARAS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                    letterSpacing: 5,
                  ),
                ),
                const Text(
                  'NUSA FOODLAB',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MASUK UNTUK MEMESAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 2,
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
                const SizedBox(height: 16),
                BrutalButton(
                  label: 'BUAT AKUN BARU',
                  primary: false,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                const Divider(thickness: 2),
                const SizedBox(height: 12),
                const Text(
                  'AKUN DEMO (KETUK UNTUK MENGISI)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BrutalButton(
                        label: 'CUSTOMER',
                        primary: false,
                        onPressed: () => _fillDemo(
                          'customer@ecommerce.local',
                          'Customer123!',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BrutalButton(
                        label: 'ADMIN',
                        primary: false,
                        onPressed: () => _fillDemo(
                          'admin@ecommerce.local',
                          'Admin123!',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
