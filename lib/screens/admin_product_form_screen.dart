import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';

/// Form tambah / edit produk (admin).
///
/// Catatan: endpoint update memakai ProductRequest yang sama dengan create
/// (category_id, name, sku wajib) — form selalu mengirim seluruh field.
class AdminProductFormScreen extends StatefulWidget {
  final Product? product;

  const AdminProductFormScreen({super.key, this.product});

  @override
  State<AdminProductFormScreen> createState() =>
      _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descController = TextEditingController();
  final _imageController = TextEditingController();
  final _weightController = TextEditingController();
  String? _categoryId;
  bool _isActive = true;
  bool _saving = false;
  bool _loadingCats = true;
  List<Category> _categories = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameController.text = p.name;
      _skuController.text = p.sku;
      _priceController.text = '${p.price}';
      _costPriceController.text = '${p.costPrice}';
      _stockController.text = '${p.stock}';
      _descController.text = p.description;
      _imageController.text = p.imageUrl;
      _weightController.text = '${p.weightGram}';
      _categoryId = p.categoryId;
      _isActive = p.isActive;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _descController.dispose();
    _imageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await context.read<ApiClient>().listCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCats = false;
        if (_categoryId == null && cats.isNotEmpty) {
          _categoryId = cats.first.id;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      showSnack(context, 'Pilih kategori dulu', isError: true);
      return;
    }
    final name = _nameController.text.trim();
    final product = Product(
      id: widget.product?.id ?? '',
      categoryId: _categoryId!,
      category: null,
      name: name,
      slug: widget.product?.slug ?? slugify(name),
      description: _descController.text.trim(),
      price: int.tryParse(_priceController.text.trim()) ?? 0,
      costPrice: int.tryParse(_costPriceController.text.trim()) ?? 0,
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      sku: _skuController.text.trim(),
      imageUrl: _imageController.text.trim(),
      weightGram: int.tryParse(_weightController.text.trim()) ?? 0,
      isActive: _isActive,
    );
    setState(() => _saving = true);
    try {
      final api = context.read<ApiClient>();
      if (_isEdit) {
        await api.updateProduct(product.id, product);
      } else {
        await api.createProduct(product);
      }
      if (!mounted) return;
      showSnack(
        context,
        _isEdit ? 'Produk diperbarui' : 'Produk dibuat',
      );
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
      appBar: AppBar(
        title: Text(_isEdit ? 'EDIT PRODUK' : 'TAMBAH PRODUK'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadingCats)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'KATEGORI'),
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) =>
                      v == null ? 'Kategori wajib dipilih' : null,
                ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _nameController,
                label: 'Nama Produk',
                validator: (v) => _required(v, 'Nama'),
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _skuController,
                label: 'SKU',
                hint: 'Contoh: SNF-NAS-002',
                validator: (v) => _required(v, 'SKU'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BrutalTextField(
                      controller: _priceController,
                      label: 'Harga (Rp)',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (int.tryParse(v ?? '') == null) {
                          return 'Harga harus angka';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrutalTextField(
                      controller: _costPriceController,
                      label: 'Harga Modal (Rp)',
                      hint: 'HPP, cth: 15000',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0) {
                          return 'Modal harus angka ≥ 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BrutalTextField(
                      controller: _stockController,
                      label: 'Stok',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (int.tryParse(v ?? '') == null) {
                          return 'Stok harus angka';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _descController,
                label: 'Deskripsi',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _imageController,
                label: 'URL Gambar',
                hint: 'https://... atau /uploads/xxx.png',
              ),
              const SizedBox(height: 14),
              BrutalTextField(
                controller: _weightController,
                label: 'Berat (gram)',
                keyboardType: TextInputType.number,
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
                    'PRODUK AKTIF (TAMPIL DI KATALOG)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BrutalButton(
                label: _isEdit ? 'SIMPAN PERUBAHAN' : 'BUAT PRODUK',
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
