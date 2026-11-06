import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'addresses_screen.dart';
import 'payment_screen.dart';

/// Checkout: pilih alamat pengiriman, pilih metode bayar (QRIS / VA),
/// buat order via POST /orders/checkout.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _selectedAddressId;
  String _paymentMethod = 'qris';
  final _notesController = TextEditingController();
  bool _busy = false;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final addrState = context.read<AddressState>();
    await addrState.refresh();
    if (!mounted) return;
    setState(() {
      _loadingAddresses = false;
      _selectedAddressId ??= addrState.defaultAddress?.id;
    });
  }

  Future<void> _checkout() async {
    final cart = context.read<CartState>().cart;
    if (cart.items.isEmpty) {
      showSnack(context, 'Keranjang masih kosong', isError: true);
      return;
    }
    if (_selectedAddressId == null) {
      showSnack(context, 'Pilih alamat pengiriman dulu', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await context.read<ApiClient>().checkout(
            addressId: _selectedAddressId!,
            paymentMethod: _paymentMethod,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      await context.read<CartState>().refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentScreen(order: order)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>().cart;
    final addrState = context.watch<AddressState>();
    final addresses = addrState.addresses;
    return Scaffold(
      appBar: AppBar(title: const Text('CHECKOUT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(title: 'Alamat Pengiriman'),
            const SizedBox(height: 10),
            if (_loadingAddresses)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else if (addresses.isEmpty)
              BrutalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BELUM ADA ALAMAT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tambahkan alamat pengiriman untuk melanjutkan checkout.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    BrutalButton(
                      label: 'TAMBAH ALAMAT',
                      icon: Icons.add_location_alt,
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddressesScreen(),
                          ),
                        );
                        _loadAddresses();
                      },
                    ),
                  ],
                ),
              )
            else
              ...addresses.map((a) {
                final selected = a.id == _selectedAddressId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BrutalCard(
                    onTap: () => setState(() => _selectedAddressId = a.id),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
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
                                        fontSize: 14,
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
                              const SizedBox(height: 2),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            if (addresses.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddressesScreen(),
                    ),
                  );
                  _loadAddresses();
                },
                icon: const Icon(Icons.edit_location_alt, size: 18),
                label: const Text(
                  'KELOLA ALAMAT',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Metode Pembayaran'),
            const SizedBox(height: 10),
            _methodTile(
              value: 'qris',
              title: 'QRIS',
              subtitle: 'Scan kode QR dari aplikasi apa pun',
              icon: Icons.qr_code_2,
            ),
            const SizedBox(height: 10),
            _methodTile(
              value: 'va_bca',
              title: 'VIRTUAL ACCOUNT BCA',
              subtitle: 'Transfer ke nomor VA yang diberikan',
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Catatan (Opsional)'),
            const SizedBox(height: 10),
            BrutalTextField(
              controller: _notesController,
              label: 'Catatan Pesanan',
              hint: 'Contoh: tidak pakai bawang',
              maxLines: 2,
            ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Ringkasan Pesanan'),
            const SizedBox(height: 10),
            BrutalCard(
              child: Column(
                children: [
                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} x${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatRupiah(item.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(thickness: 2, height: 18),
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
                        formatRupiah(cart.subtotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BrutalButton(
              label: 'BUAT PESANAN',
              icon: Icons.receipt_long,
              loading: _busy,
              onPressed: _busy ? null : _checkout,
            ),
            const SizedBox(height: 16),
          ],
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
    final selected = _paymentMethod == value;
    return BrutalCard(
      onTap: () => setState(() => _paymentMethod = value),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 22,
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.pureBlack,
              border: Border.all(color: AppTheme.pureBlack, width: 2),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.mutedOf(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
