import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'payment_screen.dart';

/// Guest Checkout (tanpa login): pilih jenis pesanan, isi data pemesan,
/// lalu "Bayar Sekarang" menembak endpoint publik
/// POST /orders/guest-checkout (tanpa JWT).
///
/// - DINE-IN: Nama + Nomor Meja (tombol cepat Meja 1-20) + Catatan.
/// - TAKEAWAY: Nama + No. WhatsApp + Catatan.
/// - DELIVERY: Nama + No. WhatsApp + alamat lengkap + Catatan.
class GuestCheckoutScreen extends StatefulWidget {
  const GuestCheckoutScreen({super.key});

  @override
  State<GuestCheckoutScreen> createState() => _GuestCheckoutScreenState();
}

class _GuestCheckoutScreenState extends State<GuestCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'dine_in'; // dine_in | takeaway | delivery
  String _method = 'qris'; // qris | va
  String? _table; // "Meja 04"

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalController = TextEditingController();

  bool _busy = false;

  static const _typeLabels = {
    'dine_in': 'DINE-IN',
    'takeaway': 'TAKEAWAY',
    'delivery': 'DELIVERY',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  bool get _needsTable => _type == 'dine_in';
  bool get _needsPhone => _type != 'dine_in';
  bool get _needsAddress => _type == 'delivery';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsTable && (_table == null || _table!.isEmpty)) {
      showSnack(context, 'Pilih nomor meja dulu', isError: true);
      return;
    }
    final cart = context.read<CartState>();
    final items = cart.guestCheckoutItems;
    if (items.isEmpty) {
      showSnack(context, 'Keranjang masih kosong', isError: true);
      return;
    }
    final notes = _notesController.text.trim();
    // Catatan dapur ditempel ke tiap item (kontrak guest-checkout
    // membawa notes per item) + top-level notes bila backend membacanya.
    final itemsWithNotes = items
        .map((i) => GuestCheckoutItem(
              productId: i.productId,
              quantity: i.quantity,
              notes: notes,
            ))
        .toList();
    setState(() => _busy = true);
    try {
      final order = await context.read<ApiClient>().guestCheckout(
            items: itemsWithNotes,
            customerName: _nameController.text.trim(),
            customerPhone:
                _needsPhone ? _phoneController.text.trim() : null,
            orderType: _type,
            tableNumber: _needsTable ? _table : null,
            notes: notes.isEmpty ? null : notes,
            deliveryAddress: _needsAddress
                ? {
                    'street': _streetController.text.trim(),
                    'city': _cityController.text.trim(),
                    'province': _provinceController.text.trim(),
                    'postal_code': _postalController.text.trim(),
                  }
                : null,
            paymentMethod: _method,
          );
      if (!mounted) return;
      await context.read<GuestOrdersState>().add(order.orderNumber);
      await cart.clearLocalCart();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(order: order, isGuest: true),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(
        context,
        e.statusCode == 404
            ? 'Endpoint guest-checkout belum aktif di backend (404). Coba lagi setelah backend live.'
            : e.message,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final items = cart.localItems;
    final subtotal = cart.subtotal;
    return Scaffold(
      appBar: AppBar(title: const Text('CHECKOUT TAMU')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(title: 'JENIS PESANAN'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _typeLabels.entries.map((e) {
                  final selected = _type == e.key;
                  return ChoiceChip(
                    label: Text(
                      e.value,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    selected: selected,
                    selectedColor: AppTheme.pureBlack,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppTheme.borderOf(context),
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: AppTheme.borderOf(context),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    onSelected: (_) => setState(() => _type = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'DATA PEMESAN'),
              const SizedBox(height: 8),
              BrutalTextField(
                controller: _nameController,
                label: 'NAMA PEMESAN',
                hint: 'Nama kamu',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              if (_needsPhone) ...[
                const SizedBox(height: 12),
                BrutalTextField(
                  controller: _phoneController,
                  label: 'NO. WHATSAPP',
                  hint: '08xxxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'No. WhatsApp wajib diisi'
                      : null,
                ),
              ],
              if (_needsTable) ...[
                const SizedBox(height: 12),
                const Text(
                  'NOMOR MEJA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(20, (i) {
                    final label = 'Meja ${i + 1}';
                    final selected = _table == label;
                    return ChoiceChip(
                      label: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      selected: selected,
                      selectedColor: AppTheme.pureBlack,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.borderOf(context),
                      ),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: AppTheme.borderOf(context),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      onSelected: (_) => setState(() => _table = label),
                    );
                  }),
                ),
              ],
              if (_needsAddress) ...[
                const SizedBox(height: 12),
                BrutalTextField(
                  controller: _streetController,
                  label: 'ALAMAT LENGKAP (JALAN)',
                  hint: 'Jl. Malioboro No. 10',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Alamat wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BrutalTextField(
                        controller: _cityController,
                        label: 'KOTA',
                        hint: 'Yogyakarta',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Kota wajib diisi'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BrutalTextField(
                        controller: _provinceController,
                        label: 'PROVINSI',
                        hint: 'DIY',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Provinsi wajib diisi'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BrutalTextField(
                  controller: _postalController,
                  label: 'KODE POS',
                  hint: '55165',
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Kode pos wajib diisi'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              BrutalTextField(
                controller: _notesController,
                label: 'CATATAN PESANAN',
                hint: 'mis. less sugar, normal ice',
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'METODE BAYAR'),
              const SizedBox(height: 8),
              _methodTile(
                value: 'qris',
                title: 'QRIS',
                subtitle: 'Scan kode QR untuk membayar',
                icon: Icons.qr_code_2,
              ),
              const SizedBox(height: 8),
              _methodTile(
                value: 'va',
                title: 'VIRTUAL ACCOUNT',
                subtitle: 'Bayar via halaman mock gateway',
                icon: Icons.account_balance,
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'RINGKASAN PESANAN'),
              const SizedBox(height: 8),
              BrutalCard(
                child: Column(
                  children: [
                    for (final item in items) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} x${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            formatRupiah(item.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    const Divider(thickness: 2, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL BAYAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formatRupiah(subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BrutalButton(
                label: _busy ? 'MEMPROSES...' : 'BAYAR SEKARANG',
                icon: Icons.payment,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'Checkout tamu tanpa login. Nomor order disimpan di perangkat agar bisa dilacak di menu Pesanan Saya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.mutedOf(context),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.pureBlack
              : Theme.of(context).cardColor,
          border: Border.all(
            color: AppTheme.borderOf(context),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.borderOf(context),
              offset: const Offset(3, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppTheme.borderOf(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppTheme.borderOf(context),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? Colors.white70
                          : AppTheme.mutedOf(context),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
