import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Admin/superadmin: CRUD voucher promo (GET/POST/PUT/DELETE
/// /admin/vouchers). Seeder backend menyediakan SLARASHEMAT, KOPIPAGI,
/// FOODLAB50.
class AdminVouchersScreen extends StatefulWidget {
  const AdminVouchersScreen({super.key});

  @override
  State<AdminVouchersScreen> createState() => _AdminVouchersScreenState();
}

class _AdminVouchersScreenState extends State<AdminVouchersScreen> {
  List<Voucher> _vouchers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ApiClient>().listVouchers();
      if (!mounted) return;
      setState(() {
        _vouchers = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Voucher v) async {
    try {
      await context.read<ApiClient>().updateVoucher(
            v.id,
            Voucher(
              id: v.id,
              code: v.code,
              discountType: v.discountType,
              discountValue: v.discountValue,
              minOrderAmount: v.minOrderAmount,
              maxDiscount: v.maxDiscount,
              quota: v.quota,
              usedCount: v.usedCount,
              isActive: !v.isActive,
              expiresAt: v.expiresAt,
            ),
          );
      if (!mounted) return;
      showSnack(
        context,
        '${v.code} ${!v.isActive ? 'DIAKTIFKAN' : 'DINONAKTIFKAN'}',
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _delete(Voucher v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS VOUCHER?'),
        content: Text('Hapus kode "${v.code}"?'),
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
    if (confirm != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteVoucher(v.id);
      if (!mounted) return;
      showSnack(context, 'Voucher ${v.code} dihapus');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _openForm({Voucher? voucher}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _VoucherFormScreen(voucher: voucher),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.pureBlack,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: AppTheme.borderOf(context), width: 2),
        ),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Gagal memuat voucher',
                  subtitle: _error!,
                )
              : _vouchers.isEmpty
                  ? const EmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'Belum ada voucher',
                      subtitle: 'Buat kode promo dengan tombol +.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.borderOf(context),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _vouchers.length,
                        itemBuilder: (context, i) {
                          final v = _vouchers[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BrutalCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v.code,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: v.isActive
                                              ? AppTheme.okGreen
                                              : AppTheme.badRed,
                                          border: Border.all(
                                            color: AppTheme.pureBlack,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          v.isActive ? 'AKTIF' : 'NONAKTIF',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${v.discountLabel}'
                                    '${v.maxDiscount > 0 ? ' • maks ${formatRupiah(v.maxDiscount)}' : ''}'
                                    '${v.minOrderAmount > 0 ? ' • min belanja ${formatRupiah(v.minOrderAmount)}' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${v.quotaLabel}'
                                    '${v.expiresAt != null && v.expiresAt!.isNotEmpty ? ' • s/d ${formatTanggal(v.expiresAt)}' : ''}',
                                    style: TextStyle(
                                      color: AppTheme.mutedOf(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: BrutalButton(
                                          label: v.isActive
                                              ? 'NONAKTIFKAN'
                                              : 'AKTIFKAN',
                                          primary: false,
                                          onPressed: () => _toggle(v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () =>
                                            _openForm(voucher: v),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppTheme.badRed,
                                        ),
                                        onPressed: () => _delete(v),
                                        tooltip: 'Hapus',
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

/// Form tambah / edit voucher.
class _VoucherFormScreen extends StatefulWidget {
  final Voucher? voucher;

  const _VoucherFormScreen({this.voucher});

  @override
  State<_VoucherFormScreen> createState() => _VoucherFormScreenState();
}

class _VoucherFormScreenState extends State<_VoucherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minController = TextEditingController(text: '0');
  final _maxController = TextEditingController(text: '0');
  final _quotaController = TextEditingController(text: '0');
  String _type = 'percentage';
  bool _isActive = true;
  bool _saving = false;
  DateTime? _expiresAt;

  bool get _isEdit => widget.voucher != null;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    if (v != null) {
      _codeController.text = v.code;
      _type = v.discountType;
      _valueController.text = '${v.discountValue}';
      _minController.text = '${v.minOrderAmount}';
      _maxController.text = '${v.maxDiscount}';
      _quotaController.text = '${v.quota}';
      _isActive = v.isActive;
      _expiresAt = DateTime.tryParse(v.expiresAt ?? '');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final voucher = Voucher(
      id: widget.voucher?.id ?? '',
      code: _codeController.text.trim().toUpperCase(),
      discountType: _type,
      discountValue: int.tryParse(_valueController.text.trim()) ?? 0,
      minOrderAmount: int.tryParse(_minController.text.trim()) ?? 0,
      maxDiscount: int.tryParse(_maxController.text.trim()) ?? 0,
      quota: int.tryParse(_quotaController.text.trim()) ?? 0,
      usedCount: widget.voucher?.usedCount ?? 0,
      isActive: _isActive,
      expiresAt: _expiresAt?.toIso8601String().substring(0, 10),
    );
    setState(() => _saving = true);
    try {
      final api = context.read<ApiClient>();
      if (_isEdit) {
        await api.updateVoucher(voucher.id, voucher);
      } else {
        await api.createVoucher(voucher);
      }
      if (!mounted) return;
      showSnack(
        context,
        _isEdit ? 'Voucher diperbarui' : 'Voucher dibuat',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'EDIT VOUCHER' : 'TAMBAH VOUCHER'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrutalTextField(
                controller: _codeController,
                label: 'Kode Voucher',
                hint: 'Contoh: SLARASHEMAT',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Kode wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'JENIS DISKON'),
                items: const [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('PERSEN (%)'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('NOMINAL TETAP (Rp)'),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'percentage'),
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _valueController,
                label: 'Nilai Diskon (% / Rp)',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Nilai harus > 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BrutalTextField(
                      controller: _minController,
                      label: 'Min Belanja (Rp)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrutalTextField(
                      controller: _maxController,
                      label: 'Maks Diskon (Rp)',
                      hint: '0 = tanpa batas',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _quotaController,
                label: 'Kuota (0 = tanpa batas)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              BrutalButton(
                label: _expiresAt == null
                    ? 'PILIH TANGGAL KEDALUWARSA'
                    : 'KEDALUWARSA: ${_expiresAt!.toIso8601String().substring(0, 10)}',
                primary: false,
                icon: Icons.calendar_today,
                onPressed: _pickDate,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v ?? true),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      width: 2,
                    ),
                  ),
                  const Text(
                    'VOUCHER AKTIF',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BrutalButton(
                label: _isEdit ? 'SIMPAN PERUBAHAN' : 'BUAT VOUCHER',
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
