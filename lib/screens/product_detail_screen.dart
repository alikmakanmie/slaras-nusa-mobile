import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Detail produk: gambar besar, deskripsi, stok, stepper kuantitas,
/// tambah ke keranjang.
class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;
  int _qty = 1;
  bool _adding = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await context.read<ApiClient>().getProduct(_product.id);
      if (!mounted) return;
      setState(() {
        _product = fresh;
        if (_qty > fresh.stock && fresh.stock > 0) _qty = fresh.stock;
      });
    } catch (_) {
      // Biarkan data awal dari daftar bila refresh gagal.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      // Member -> API /cart; tamu -> keranjang lokal di perangkat.
      await context.read<CartState>().addProduct(_product, _qty);
      if (!mounted) return;
      showSnack(context, '${_product.name} x$_qty masuk keranjang');
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outOfStock = _product.stock <= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('DETAIL MENU')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ProductImage(
                  imageUrl: _product.imageUrl,
                  fallbackName: _product.name,
                  height: 260,
                ),
                if (_loading)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_product.categoryName.isNotEmpty)
                        StatusBadge(status: _product.categoryName),
                      const Spacer(),
                      Text(
                        'SKU: ${_product.sku}',
                        style: TextStyle(
                          color: AppTheme.mutedOf(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatRupiah(_product.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        outOfStock ? Icons.cancel : Icons.check_circle,
                        size: 18,
                        color: outOfStock
                            ? AppTheme.badRed
                            : AppTheme.okGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        outOfStock
                            ? 'STOK HABIS'
                            : 'STOK TERSEDIA: ${_product.stock}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1,
                          color: outOfStock
                              ? AppTheme.badRed
                              : AppTheme.okGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_product.weightGram} GRAM',
                        style: TextStyle(
                          color: AppTheme.mutedOf(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(title: 'Deskripsi'),
                  const SizedBox(height: 8),
                  Text(
                    _product.description.isEmpty
                        ? 'Tidak ada deskripsi untuk menu ini.'
                        : _product.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'JUMLAH',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      QtyStepper(
                        value: _qty,
                        max: _product.stock > 0 ? _product.stock : 1,
                        onChanged: (v) => setState(() => _qty = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subtotal: ${formatRupiah(_product.price * _qty)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  BrutalButton(
                    label: outOfStock
                        ? 'STOK HABIS'
                        : 'TAMBAH KE KERANJANG',
                    icon: Icons.add_shopping_cart,
                    loading: _adding,
                    onPressed: outOfStock || _adding ? null : _addToCart,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
