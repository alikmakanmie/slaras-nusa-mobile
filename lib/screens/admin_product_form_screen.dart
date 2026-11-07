import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
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
  bool _uploading = false;
  bool _loadingCats = true;
  List<Category> _categories = [];
  List<ModifierGroup> _modifiers = [];

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
      _modifiers = List.of(p.modifiers);
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

  Future<void> _pickAndUpload() async {
    final api = context.read<ApiClient>();
    // Pemilih gambar sistem (photo picker Android) — tanpa file_picker:
    // file_picker 8.x mem-pin AGP 7.4.2 di buildscript-nya, tak tersedia
    // di repo Maven offline VM (hanya AGP 8.11.1/8.13.1/9.1.0) sehingga
    // build Gradle gagal. image_picker_android mem-pin AGP 8.13.1.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Ukuran file maksimal 5MB', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await api.uploadImage(bytes, picked.name);
      if (!mounted) return;
      setState(() => _imageController.text = url);
      showSnack(context, 'Foto berhasil diunggah');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      modifiers: _modifiers,
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

  void _updateOption(
    int gi,
    int oi, {
    String? name,
    int? priceDelta,
    int? costDelta,
  }) {
    final g = _modifiers[gi];
    final o = g.options[oi];
    final opts = List<ModifierOption>.of(g.options);
    opts[oi] = ModifierOption(
      name: name ?? o.name,
      priceDelta: priceDelta ?? o.priceDelta,
      costDelta: costDelta ?? o.costDelta,
    );
    _modifiers[gi] = ModifierGroup(
      name: g.name,
      type: g.type,
      options: opts,
    );
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
              const SectionTitle(title: 'Varian / Add-On'),
              const SizedBox(height: 8),
              Text(
                'Varian tersimpan ke modifiers_json produk. '
                'Harga & HPP add-on ikut dihitung di struk dan profit.',
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
                      label: 'PAKAI VARIAN BAWAAN',
                      primary: false,
                      icon: Icons.auto_awesome,
                      onPressed: () => setState(
                        () => _modifiers = defaultModifiers(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrutalButton(
                      label: 'TAMBAH GRUP',
                      primary: false,
                      icon: Icons.add,
                      onPressed: () => setState(
                        () => _modifiers = [
                          ..._modifiers,
                          const ModifierGroup(
                            name: 'Grup Baru',
                            type: 'single',
                            options: [ModifierOption(name: 'Opsi 1')],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              for (var gi = 0; gi < _modifiers.length; gi++) ...[
                const SizedBox(height: 12),
                BrutalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _modifiers[gi].name,
                              decoration: const InputDecoration(
                                labelText: 'NAMA GRUP',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                              onChanged: (v) {
                                final g = _modifiers[gi];
                                _modifiers[gi] = ModifierGroup(
                                  name: v,
                                  type: g.type,
                                  options: g.options,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _modifiers[gi].type,
                            items: const [
                              DropdownMenuItem(
                                value: 'single',
                                child: Text('PILIH 1'),
                              ),
                              DropdownMenuItem(
                                value: 'multi',
                                child: Text('BISA BANYAK'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              final g = _modifiers[gi];
                              setState(
                                () => _modifiers[gi] = ModifierGroup(
                                  name: g.name,
                                  type: v,
                                  options: g.options,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.badRed,
                            ),
                            onPressed: () => setState(
                              () => _modifiers.removeAt(gi),
                            ),
                            tooltip: 'Hapus grup',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var oi = 0;
                          oi < _modifiers[gi].options.length;
                          oi++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue:
                                      _modifiers[gi].options[oi].name,
                                  decoration: const InputDecoration(
                                    labelText: 'OPSI',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onChanged: (v) =>
                                      _updateOption(gi, oi, name: v),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue:
                                      '${_modifiers[gi].options[oi].priceDelta}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '+HARGA',
                                  ),
                                  onChanged: (v) => _updateOption(
                                    gi,
                                    oi,
                                    priceDelta: int.tryParse(v) ?? 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue:
                                      '${_modifiers[gi].options[oi].costDelta}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '+HPP',
                                  ),
                                  onChanged: (v) => _updateOption(
                                    gi,
                                    oi,
                                    costDelta: int.tryParse(v) ?? 0,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(
                                  () {
                                    final g = _modifiers[gi];
                                    _modifiers[gi] = ModifierGroup(
                                      name: g.name,
                                      type: g.type,
                                      options: List.of(g.options)
                                        ..removeAt(oi),
                                    );
                                  },
                                ),
                                tooltip: 'Hapus opsi',
                              ),
                            ],
                          ),
                        ),
                      BrutalButton(
                        label: 'TAMBAH OPSI',
                        primary: false,
                        icon: Icons.add,
                        onPressed: () => setState(
                          () {
                            final g = _modifiers[gi];
                            _modifiers[gi] = ModifierGroup(
                              name: g.name,
                              type: g.type,
                              options: [
                                ...g.options,
                                const ModifierOption(name: 'Opsi Baru'),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              const SizedBox(height: 10),
              BrutalButton(
                label: _uploading
                    ? 'MENGUNGGAH...'
                    : 'UPLOAD FOTO DARI PERANGKAT',
                icon: Icons.upload,
                loading: _uploading,
                onPressed: _uploading ? null : _pickAndUpload,
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
