import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'home_shell.dart';
import 'floating_cart_bar.dart';
import 'product_detail_screen.dart';

/// Beranda: katalog produk SLARAS NUSA FOODLAB dengan pencarian real-time
/// (debounce), filter kategori, dan filter rentang harga.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  Timer? _debounce;

  List<Category> _categories = [];
  List<Product> _products = [];
  String? _selectedCategoryId;
  bool _loadingCategories = true;
  bool _loadingProducts = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _showPriceFilter = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadProducts({required bool reset}) async {
    if (reset) {
      setState(() {
        _loadingProducts = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await _api.listProducts(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        categoryId: _selectedCategoryId,
        minPrice: int.tryParse(_minPriceController.text.trim()),
        maxPrice: int.tryParse(_maxPriceController.text.trim()),
        page: _page,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _totalPages = result.totalPages;
        if (reset) {
          _products = result.items;
        } else {
          _products = [..._products, ...result.items];
        }
        _loadingProducts = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingProducts = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadProducts(reset: true);
    });
  }

  Future<void> _refresh() async {
    await _loadCategories();
    await _loadProducts(reset: true);
  }

  Future<void> _addToCart(Product product) async {
    try {
      // Member -> API /cart; tamu -> keranjang lokal di perangkat.
      await context.read<CartState>().addProduct(product, 1);
      if (!mounted) return;
      showSnack(context, '${product.name} masuk keranjang');
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartState>().totalItems;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SLARAS NUSA FOODLAB'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              backgroundColor: AppTheme.badRed,
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () {
              // Pindah ke tab keranjang lewat HomeShell.
              HomeShell.of(context)?.goToTab(1);
            },
            tooltip: 'Keranjang',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Fokus ke kolom pencarian di bawah AppBar.
              FocusScope.of(context).requestFocus(FocusNode());
            },
            tooltip: 'Cari',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.borderOf(context),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner hero brutal.
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.pureBlack,
                  border: Border.all(color: AppTheme.pureBlack, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.shadowOf(context),
                      offset: const Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAKAN ENAK,',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'HARGA BERSAHABAT.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Menu rumahan khas Slaras, dimasak segar setiap hari.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Pencarian.
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'CARI MENU... (MIS. NASI GORENG)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadProducts(reset: true);
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter kategori.
              SizedBox(
                height: 42,
                child: _loadingCategories
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: BrutalChip(
                              label: 'Semua',
                              selected: _selectedCategoryId == null,
                              onTap: () {
                                setState(() => _selectedCategoryId = null);
                                _loadProducts(reset: true);
                              },
                            ),
                          ),
                          for (final cat in _categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: cat.imageUrl.isEmpty
                                  ? BrutalChip(
                                      label: cat.name,
                                      selected:
                                          _selectedCategoryId == cat.id,
                                      onTap: () {
                                        setState(
                                          () => _selectedCategoryId = cat.id,
                                        );
                                        _loadProducts(reset: true);
                                      },
                                    )
                                  : _CategoryChip(
                                      category: cat,
                                      selected:
                                          _selectedCategoryId == cat.id,
                                      onTap: () {
                                        setState(
                                          () => _selectedCategoryId = cat.id,
                                        );
                                        _loadProducts(reset: true);
                                      },
                                    ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              // Filter harga.
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showPriceFilter = !_showPriceFilter);
                      },
                      child: Text(
                        _showPriceFilter
                            ? '▲ SEMBUNYIKAN FILTER HARGA'
                            : '▼ FILTER HARGA',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (_minPriceController.text.isNotEmpty ||
                      _maxPriceController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _minPriceController.clear();
                        _maxPriceController.clear();
                        _loadProducts(reset: true);
                      },
                      child: const Text(
                        'RESET',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                ],
              ),
              if (_showPriceFilter) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'HARGA MIN (RP)',
                          hintText: '0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'HARGA MAKS (RP)',
                          hintText: '100000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: BrutalButton(
                        label: 'OK',
                        expanded: false,
                        onPressed: () => _loadProducts(reset: true),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const SectionTitle(title: 'Menu Pilihan'),
              const SizedBox(height: 12),
              if (_loadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else if (_error != null)
                EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Gagal memuat menu',
                  subtitle: _error!,
                )
              else if (_products.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: 'Menu tidak ditemukan',
                  subtitle: 'Coba kata kunci atau filter lain.',
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final p = _products[i];
                    return _ProductCard(
                      product: p,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: p),
                          ),
                        );
                      },
                      onAdd: () => _addToCart(p),
                    );
                  },
                ),
              if (!_loadingProducts &&
                  _products.isNotEmpty &&
                  _page < _totalPages) ...[
                const SizedBox(height: 16),
                BrutalButton(
                  label: _loadingMore ? 'MEMUAT...' : 'MUAT LEBIH BANYAK',
                  primary: false,
                  loading: _loadingMore,
                  onPressed: _loadingMore
                      ? null
                      : () {
                          setState(() => _page += 1);
                          _loadProducts(reset: false);
                        },
                ),
              ],
              // Ruang ekstra di bawah agar item terakhir tidak tertutup
              // Floating Cart Bar saat bar muncul.
              SizedBox(height: cartCount > 0 ? 130 : 24),
            ],
          ),
        ),
          ),
          // Floating Cart Bar: muncul saat keranjang berisi >= 1 item.
          if (cartCount > 0)
            const Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: FloatingCartBar(),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock <= 0;
    return BrutalCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ProductImage(
                imageUrl: product.imageUrl,
                fallbackName: product.name,
                height: 110,
              ),
              if (outOfStock)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.badRed,
                      border: Border.all(color: AppTheme.pureBlack, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: const Text(
                      'HABIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.categoryName.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.mutedOf(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatRupiah(product.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Stok: ${product.stock}',
                  style: TextStyle(
                    color: AppTheme.mutedOf(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: BrutalButton(
                    label: outOfStock ? 'HABIS' : '+ KERANJANG',
                    onPressed: outOfStock ? null : onAdd,
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

/// Chip kategori dengan thumbnail gambar (dipakai bila kategori punya
/// image_url; bila gambar gagal dimuat, tampilkan kotak hitam + inisial).
class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? (isDark ? Colors.white : AppTheme.pureBlack)
        : AppTheme.surfaceOf(context);
    final fg = selected
        ? (isDark ? AppTheme.pureBlack : Colors.white)
        : Theme.of(context).colorScheme.onSurface;
    final url = AppConfig.resolveImageUrl(category.imageUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: AppTheme.borderOf(context), width: 2),
          borderRadius: BorderRadius.circular(2),
          boxShadow: selected
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.shadowOf(context),
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.network(
                url,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 28,
                  height: 28,
                  color: AppTheme.pureBlack,
                  alignment: Alignment.center,
                  child: Text(
                    category.name.isEmpty
                        ? 'S'
                        : category.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.name.toUpperCase(),
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
