import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Admin: kelola kategori (list, tambah, edit, hapus).
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<Category> _categories = [];
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
      final cats = await context.read<ApiClient>().listCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
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

  Future<void> _delete(Category c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS KATEGORI?'),
        content: Text(
          'Hapus kategori "${c.name}"? Produk di dalamnya bisa ikut bermasalah.',
        ),
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
      await context.read<ApiClient>().deleteCategory(c.id);
      if (!mounted) return;
      showSnack(context, 'Kategori dihapus');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _openForm({Category? category}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CategoryFormScreen(category: category),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KELOLA KATEGORI')),
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
                  title: 'Gagal memuat kategori',
                  subtitle: _error!,
                )
              : _categories.isEmpty
                  ? const EmptyState(
                      icon: Icons.category_outlined,
                      title: 'Belum ada kategori',
                      subtitle: 'Tambahkan kategori dengan tombol +.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.borderOf(context),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (context, i) {
                          final c = _categories[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BrutalCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.pureBlack,
                                      border: Border.all(
                                        color: AppTheme.borderOf(context),
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      c.name.isEmpty
                                          ? '?'
                                          : c.name.characters.first
                                              .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
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
                                          c.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          c.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.mutedOf(context),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _openForm(category: c),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppTheme.badRed,
                                    ),
                                    onPressed: () => _delete(c),
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

class _CategoryFormScreen extends StatefulWidget {
  final Category? category;

  const _CategoryFormScreen({this.category});

  @override
  State<_CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<_CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _imageController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameController.text = c.name;
      _descController.text = c.description;
      _imageController.text = c.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiClient>();
      final category = Category(
        id: widget.category?.id ?? '',
        name: _nameController.text.trim(),
        slug: widget.category?.slug ?? '',
        description: _descController.text.trim(),
        imageUrl: _imageController.text.trim(),
      );
      if (widget.category != null) {
        await api.updateCategory(category.id, category);
      } else {
        await api.createCategory(category);
      }
      if (!mounted) return;
      showSnack(
        context,
        widget.category != null
            ? 'Kategori diperbarui'
            : 'Kategori dibuat',
      );
      Navigator.of(context).pop();
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
        title: Text(
          widget.category != null ? 'EDIT KATEGORI' : 'TAMBAH KATEGORI',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrutalTextField(
                controller: _nameController,
                label: 'Nama Kategori',
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Nama minimal 2 karakter';
                  }
                  return null;
                },
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
                hint: 'https://... (opsional)',
              ),
              const SizedBox(height: 20),
              BrutalButton(
                label: 'SIMPAN',
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
