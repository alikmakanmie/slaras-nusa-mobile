import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'checkout_screen.dart';
import 'guest_checkout_screen.dart';
import 'product_detail_screen.dart';

/// Keranjang belanja: ubah kuantitas (+/-), hapus item, subtotal sinkron API.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<CartState>().refresh();
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _setQty(String itemId, int qty) async {
    final cartState = context.read<CartState>();
    final loggedIn = context.read<AuthState>().isLoggedIn;
    try {
      if (loggedIn) {
        await cartState.setQty(itemId, qty);
      } else {
        // itemId di mode tamu = productId.
        await cartState.setLocalQty(itemId, qty);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _remove(String itemId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS ITEM?'),
        content: Text('Hapus "$name" dari keranjang?'),
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
    final cartState = context.read<CartState>();
    final loggedIn = context.read<AuthState>().isLoggedIn;
    try {
      if (loggedIn) {
        await cartState.remove(itemId);
      } else {
        // itemId di mode tamu = productId.
        await cartState.removeLocal(itemId);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartState>();
    final loggedIn = context.watch<AuthState>().isLoggedIn;
    // Tamu: keranjang lokal di perangkat + checkout tamu.
    if (!loggedIn) return _buildGuestCart(context, cartState);
    final cart = cartState.cart;
    return Scaffold(
      appBar: AppBar(title: const Text('KERANJANG')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : cart.items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Keranjang masih kosong',
                  subtitle: 'Yuk pilih menu favoritmu dari beranda.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.borderOf(context),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final item in cart.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: BrutalCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: item.product == null
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductDetailScreen(
                                                product: item.product!,
                                              ),
                                            ),
                                          );
                                        },
                                  child: ClipRRect(
                                    child: ProductImage(
                                      imageUrl: item.product?.imageUrl,
                                      fallbackName: item.productName,
                                      height: 84,
                                      width: 84,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatRupiah(item.price),
                                        style: TextStyle(
                                          color: AppTheme.mutedOf(context),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          QtyStepper(
                                            value: item.quantity,
                                            max: item.product?.stock ?? 999,
                                            onChanged: (v) =>
                                                _setQty(item.id, v),
                                          ),
                                          const Spacer(),
                                          Text(
                                            formatRupiah(item.subtotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.badRed,
                                  ),
                                  onPressed: () =>
                                      _remove(item.id, item.productName),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      BrutalCard(
                        child: Column(
                          children: [
                            _row('TOTAL ITEM', '${cart.totalItems} item'),
                            const SizedBox(height: 6),
                            _row('SUBTOTAL', formatRupiah(cart.subtotal)),
                            const SizedBox(height: 6),
                            _row('ONGKIR', 'Gratis (promo Foodlab)'),
                            const Divider(thickness: 2, height: 20),
                            _row(
                              'TOTAL BAYAR',
                              formatRupiah(cart.subtotal),
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      BrutalButton(
                        label: 'CHECKOUT',
                        icon: Icons.arrow_forward,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CheckoutScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }

  /// Keranjang tamu: item lokal (snapshot produk) + checkout tamu.
  Widget _buildGuestCart(BuildContext context, CartState cartState) {
    final items = cartState.localItems;
    return Scaffold(
      appBar: AppBar(title: const Text('KERANJANG')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Keranjang masih kosong',
                  subtitle:
                      'Yuk pilih menu favoritmu dari beranda. Tanpa login, keranjang tersimpan di perangkat ini.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.borderOf(context),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const BrutalCard(
                        child: Row(
                          children: [
                            Icon(Icons.person_outline),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'MODE TAMU — login untuk simpan keranjang di akun.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: BrutalCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductImage(
                                  imageUrl: item.imageUrl,
                                  fallbackName: item.name,
                                  height: 84,
                                  width: 84,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatRupiah(item.price),
                                        style: TextStyle(
                                          color: AppTheme.mutedOf(context),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          QtyStepper(
                                            value: item.quantity,
                                            max: 99,
                                            onChanged: (v) => _setQty(
                                              item.productId,
                                              v,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            formatRupiah(item.subtotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.badRed,
                                  ),
                                  onPressed: () =>
                                      _remove(item.productId, item.name),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      BrutalCard(
                        child: Column(
                          children: [
                            _row('TOTAL ITEM',
                                '${cartState.totalItems} item'),
                            const SizedBox(height: 6),
                            _row('SUBTOTAL',
                                formatRupiah(cartState.subtotal)),
                            const SizedBox(height: 6),
                            _row('ONGKIR', 'Dihitung saat checkout'),
                            const Divider(thickness: 2, height: 20),
                            _row(
                              'TOTAL BAYAR',
                              formatRupiah(cartState.subtotal),
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      BrutalButton(
                        label: 'CHECKOUT SEBAGAI TAMU',
                        icon: Icons.arrow_forward,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GuestCheckoutScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            fontSize: bold ? 16 : 13,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
