import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'admin_categories_screen.dart';
import 'admin_product_form_screen.dart';

/// Admin: kelola produk (list, cari, tambah, edit, hapus).
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<ApiClient>().listProducts(
            search: search,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        _products = result.items;
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

  Future<void> _delete(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS PRODUK?'),
        content: Text('Hapus "${p.name}" (SKU ${p.sku})?'),
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
      await context.read<ApiClient>().deleteProduct(p.id);
      if (!mounted) return;
      showSnack(context, 'Produk dihapus');
      _load(search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim());
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _changeStock(Product p, int delta) async {
    final next = p.stock + delta;
    if (next < 0) return;
    final idx = _products.indexWhere((e) => e.id == p.id);
    if (idx < 0) return;
    final old = _products[idx];
    setState(() => _products[idx] = p.copyWith(stock: next));
    try {
      await context.read<ApiClient>().updateProduct(
            p.id,
            p.copyWith(stock: next),
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _products[idx] = old);
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminProductFormScreen(product: product),
      ),
    );
    _load(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: BrutalButton(
              label: 'KELOLA KATEGORI',
              primary: false,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminCategoriesScreen(),
                  ),
                );
                _load(
                  search: _searchController.text.trim().isEmpty
                      ? null
                      : _searchController.text.trim(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _load(
                search: v.trim().isEmpty ? null : v.trim(),
              ),
              decoration: InputDecoration(
                hintText: 'CARI PRODUK...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off,
                        title: 'Gagal memuat produk',
                        subtitle: _error!,
                      )
                    : _products.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Belum ada produk',
                            subtitle: 'Tambahkan produk dengan tombol +.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(
                              search: _searchController.text.trim().isEmpty
                                  ? null
                                  : _searchController.text.trim(),
                            ),
                            color: AppTheme.borderOf(context),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _products.length,
                              itemBuilder: (context, i) {
                                final p = _products[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: BrutalCard(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ProductImage(
                                          imageUrl: p.imageUrl,
                                          fallbackName: p.name,
                                          height: 72,
                                          width: 72,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                '${p.sku} • ${p.categoryName}',
                                                style: TextStyle(
                                                  color: AppTheme.mutedOf(
                                                    context,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                '${formatRupiah(p.price)} • Stok ${p.stock} • ${p.isActive ? 'AKTIF' : 'NONAKTIF'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Text(
                                                    'STOK ',
                                                    style: TextStyle(
                                                      color: AppTheme.mutedOf(
                                                        context,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 11,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                  QtyStepper(
                                                    value: p.stock,
                                                    min: 0,
                                                    onChanged: (v) =>
                                                        _changeStock(
                                                      p,
                                                      v - p.stock,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () =>
                                                  _openForm(product: p),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.badRed,
                                              ),
                                              onPressed: () => _delete(p),
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
          ),
        ],
      ),
    );
  }
}
