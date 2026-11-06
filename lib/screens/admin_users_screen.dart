import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Superadmin: kelola semua user & akses.
/// (Tab ini hanya muncul bila role == superadmin; layar ini juga berjaga
/// sendiri bila dibuka tanpa hak.)
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<User> _users = [];
  UserStats _stats = UserStats.empty;
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  String? _roleFilter;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final api = context.read<ApiClient>();
      final stats = await api.getUserStats();
      final result = await api.listUsers(
        page: _page,
        limit: 20,
        search: _search.isEmpty ? null : _search,
        role: _roleFilter,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _totalPages = result.totalPages;
        _users = reset ? result.items : [..._users, ...result.items];
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _changeRole(User u, String role) async {
    if (role == u.role) return;
    try {
      await context.read<ApiClient>().updateUserRole(u.id, role);
      if (!mounted) return;
      showSnack(context, '${u.email} -> ${role.toUpperCase()}');
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _toggleActive(User u) async {
    try {
      await context.read<ApiClient>().updateUserStatus(u.id, !u.isActive);
      if (!mounted) return;
      showSnack(
        context,
        u.isActive ? '${u.email} dinonaktifkan' : '${u.email} diaktifkan',
      );
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _delete(User u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS USER?'),
        content: Text('Hapus akun ${u.name} (${u.email})?'),
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
      await context.read<ApiClient>().deleteUser(u.id);
      if (!mounted) return;
      showSnack(context, 'User dihapus');
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _openAddUser() async {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    final phoneC = TextEditingController();
    var role = 'admin';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('TAMBAH USER / STAF'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'NAMA'),
                    ),
                    TextField(
                      controller: emailC,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'EMAIL'),
                    ),
                    TextField(
                      controller: passC,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'KATA SANDI (MIN 8)',
                      ),
                    ),
                    TextField(
                      controller: phoneC,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'NO HP (OPSIONAL)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'ROLE'),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('ADMIN TOKO'),
                        ),
                        DropdownMenuItem(
                          value: 'superadmin',
                          child: Text('SUPERADMIN'),
                        ),
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('CUSTOMER'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => role = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('BATAL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('SIMPAN'),
                ),
              ],
            );
          },
        );
      },
    );
    final name = nameC.text.trim();
    final email = emailC.text.trim();
    final pass = passC.text;
    final phone = phoneC.text.trim();
    nameC.dispose();
    emailC.dispose();
    passC.dispose();
    phoneC.dispose();
    if (saved != true || !mounted) return;
    if (name.isEmpty || !email.contains('@') || pass.length < 8) {
      showSnack(
        context,
        'Nama, email valid, dan kata sandi min 8 karakter wajib diisi',
        isError: true,
      );
      return;
    }
    try {
      await context.read<ApiClient>().createUser(
            name: name,
            email: email,
            password: pass,
            phone: phone,
            role: role,
          );
      if (!mounted) return;
      showSnack(context, 'User $email dibuat');
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Widget _statCard(String label, int value) {
    return Expanded(
      child: BrutalCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedOf(context),
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().user;
    if (me == null || !me.isSuperAdmin) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Akses ditolak',
        subtitle: 'Halaman ini khusus Superadmin.',
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddUser,
        backgroundColor: AppTheme.pureBlack,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: AppTheme.borderOf(context), width: 2),
        ),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _statCard('TOTAL', _stats.total),
                const SizedBox(width: 8),
                _statCard('ADMIN', _stats.admin),
                const SizedBox(width: 8),
                _statCard('SUPERADMIN', _stats.superadmin),
                const SizedBox(width: 8),
                _statCard('NONAKTIF', _stats.inactive),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _search = v.trim();
                _load(reset: true);
              },
              decoration: InputDecoration(
                hintText: 'CARI NAMA / EMAIL...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _search = '';
                    _load(reset: true);
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final entry in <(String?, String)>[
                    (null, 'Semua'),
                    ('admin', 'Admin'),
                    ('superadmin', 'Superadmin'),
                    ('customer', 'Customer'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: BrutalChip(
                        label: entry.$2,
                        selected: _roleFilter == entry.$1,
                        onTap: () {
                          setState(() => _roleFilter = entry.$1);
                          _load(reset: true);
                        },
                      ),
                    ),
                ],
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
                        title: 'Gagal memuat user',
                        subtitle: _error!,
                      )
                    : _users.isEmpty
                        ? const EmptyState(
                            icon: Icons.group_outlined,
                            title: 'Tidak ada user',
                            subtitle: 'Coba filter lain.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            color: AppTheme.borderOf(context),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _users.length + 1,
                              itemBuilder: (context, i) {
                                if (i == _users.length) {
                                  if (_page >= _totalPages) {
                                    return const SizedBox(height: 16);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: BrutalButton(
                                      label: _loadingMore
                                          ? 'MEMUAT...'
                                          : 'MUAT LEBIH BANYAK',
                                      primary: false,
                                      loading: _loadingMore,
                                      onPressed: _loadingMore
                                          ? null
                                          : () {
                                              setState(() => _page += 1);
                                              _load(reset: false);
                                            },
                                    ),
                                  );
                                }
                                final u = _users[i];
                                final isMe = me.id == u.id;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: BrutalCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                u.name.isEmpty
                                                    ? u.email
                                                    : u.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: u.role == 'superadmin'
                                                    ? AppTheme.badRed
                                                    : AppTheme.surfaceOf(
                                                        context,
                                                      ),
                                                border: Border.all(
                                                  color:
                                                      AppTheme.pureBlack,
                                                  width: 2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              child: Text(
                                                u.roleLabel,
                                                style: TextStyle(
                                                  color: u.role ==
                                                          'superadmin'
                                                      ? Colors.white
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 10,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          u.email,
                                          style: TextStyle(
                                            color: AppTheme.mutedOf(context),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          u.isActive
                                              ? 'AKTIF'
                                              : 'NONAKTIF (SUSPENDED)',
                                          style: TextStyle(
                                            color: u.isActive
                                                ? null
                                                : AppTheme.badRed,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            DropdownButton<String>(
                                              value: u.role,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'customer',
                                                  child: Text('CUSTOMER'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'admin',
                                                  child: Text('ADMIN'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'superadmin',
                                                  child: Text('SUPERADMIN'),
                                                ),
                                              ],
                                              onChanged: isMe
                                                  ? null
                                                  : (v) {
                                                      if (v != null) {
                                                        _changeRole(u, v);
                                                      }
                                                    },
                                            ),
                                            OutlinedButton(
                                              onPressed: isMe
                                                  ? null
                                                  : () => _toggleActive(u),
                                              child: Text(
                                                u.isActive
                                                    ? 'SUSPEND'
                                                    : 'AKTIFKAN',
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.badRed,
                                              ),
                                              tooltip: 'Hapus',
                                              onPressed: isMe
                                                  ? null
                                                  : () => _delete(u),
                                            ),
                                          ],
                                        ),
                                        if (isMe)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 6),
                                            child: Text(
                                              'Akun sendiri: role/status/hapus dilindungi.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
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
