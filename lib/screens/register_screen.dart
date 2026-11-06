import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../widgets.dart';
import 'home_shell.dart';

/// Layar registrasi akun baru. Setelah sukses, login otomatis.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final auth = context.read<AuthState>();
    try {
      await auth.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _phoneController.text.trim(),
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthState>().busy;
    return Scaffold(
      appBar: AppBar(title: const Text('DAFTAR AKUN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrutalTextField(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  hint: 'Nama kamu',
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Nama minimal 2 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                  controller: _phoneController,
                  label: 'No. HP',
                  hint: '08xxxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                BrutalTextField(
                  controller: _passwordController,
                  label: 'Kata Sandi',
                  hint: 'Minimal 8 karakter',
                  obscure: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Kata sandi minimal 8 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                BrutalTextField(
                  controller: _confirmController,
                  label: 'Ulangi Kata Sandi',
                  hint: 'Ketik ulang kata sandi',
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
                    if (v != _passwordController.text) {
                      return 'Konfirmasi kata sandi tidak cocok';
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
                  label: 'DAFTAR & MASUK',
                  icon: Icons.person_add,
                  loading: busy,
                  onPressed: busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
