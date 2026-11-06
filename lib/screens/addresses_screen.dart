import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Manajemen alamat pengiriman (CRUD + set default).
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressState>().refresh();
    });
  }

  Future<void> _delete(Address a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS ALAMAT?'),
        content: Text('Hapus alamat "${a.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await context.read<AddressState>().remove(a.id);
      if (!mounted) return;
      showSnack(context, 'Alamat dihapus');
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _setDefault(Address a) async {
    try {
      await context.read<AddressState>().setDefault(a.id);
      if (!mounted) return;
      showSnack(context, '"${a.label}" jadi alamat utama');
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addrState = context.watch<AddressState>();
    return Scaffold(
      appBar: AppBar(title: const Text('ALAMAT SAYA')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddressFormScreen()),
          );
        },
        backgroundColor: AppTheme.pureBlack,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: AppTheme.borderOf(context), width: 2),
        ),
        child: const Icon(Icons.add),
      ),
      body: addrState.loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : addrState.addresses.isEmpty
              ? const EmptyState(
                  icon: Icons.location_off,
                  title: 'Belum ada alamat',
                  subtitle: 'Tambahkan alamat pengiriman dengan tombol +.',
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      context.read<AddressState>().refresh(),
                  color: AppTheme.borderOf(context),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: addrState.addresses.length,
                    itemBuilder: (context, i) {
                      final a = addrState.addresses[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BrutalCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.label.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (a.isDefault)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.pureBlack,
                                        border: Border.all(
                                          color: AppTheme.pureBlack,
                                          width: 2,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      child: const Text(
                                        'UTAMA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${a.recipientName} • ${a.phone}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                a.fullAddress,
                                style: TextStyle(
                                  color: AppTheme.mutedOf(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (!a.isDefault)
                                    Expanded(
                                      child: BrutalButton(
                                        label: 'JADIKAN UTAMA',
                                        primary: false,
                                        onPressed: () => _setDefault(a),
                                      ),
                                    ),
                                  if (!a.isDefault) const SizedBox(width: 10),
                                  SizedBox(
                                    width: 110,
                                    child: BrutalButton(
                                      label: 'HAPUS',
                                      primary: false,
                                      onPressed: () => _delete(a),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Form tambah alamat baru.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Rumah');
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalController = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AddressState>().create(
            Address(
              id: '',
              label: _labelController.text.trim(),
              recipientName: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              street: _streetController.text.trim(),
              city: _cityController.text.trim(),
              province: _provinceController.text.trim(),
              postalCode: _postalController.text.trim(),
              isDefault: _isDefault,
            ),
          );
      if (!mounted) return;
      showSnack(context, 'Alamat ditambahkan');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TAMBAH ALAMAT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrutalTextField(
                controller: _labelController,
                label: 'Label Alamat',
                hint: 'Rumah / Kantor / Kos',
                validator: (v) => _required(v, 'Label'),
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _nameController,
                label: 'Nama Penerima',
                validator: (v) => _required(v, 'Nama penerima'),
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _phoneController,
                label: 'No. HP Penerima',
                keyboardType: TextInputType.phone,
                validator: (v) => _required(v, 'No. HP'),
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _streetController,
                label: 'Jalan & Nomor Rumah',
                maxLines: 2,
                validator: (v) => _required(v, 'Alamat jalan'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BrutalTextField(
                      controller: _cityController,
                      label: 'Kota',
                      validator: (v) => _required(v, 'Kota'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrutalTextField(
                      controller: _provinceController,
                      label: 'Provinsi',
                      validator: (v) => _required(v, 'Provinsi'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _postalController,
                label: 'Kode Pos',
                keyboardType: TextInputType.number,
                validator: (v) => _required(v, 'Kode pos'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v ?? false),
                    side: BorderSide(
                      color: AppTheme.borderOf(context),
                      width: 2,
                    ),
                  ),
                  const Text(
                    'JADIKAN ALAMAT UTAMA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BrutalButton(
                label: 'SIMPAN ALAMAT',
                icon: Icons.save,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
