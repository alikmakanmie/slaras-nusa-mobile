import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

/// Admin: kelola semua pesanan + ubah status
/// (processing, shipped, completed — sesuai transisi backend).
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  String? _statusFilter;
  Timer? _autoRefresh;

  static const _statuses = [
    'pending',
    'paid',
    'processing',
    'shipped',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    // Antrean dapur: segarkan otomatis tiap 30 detik.
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) _load(reset: true);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
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
      final result = await context.read<ApiClient>().listAllOrders(
            page: _page,
            limit: 20,
          );
      if (!mounted) return;
      var items = result.items;
      if (_statusFilter != null) {
        items = items.where((o) => o.status == _statusFilter).toList();
      }
      setState(() {
        _totalPages = result.totalPages;
        _orders = reset ? items : [..._orders, ...items];
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

  /// Status berikutnya yang valid dari status saat ini (backend juga
  /// memvalidasi; pilihan di sini hanya menampilkan yang masuk akal).
  List<String> _nextStatuses(String current) {
    switch (current) {
      case 'paid':
        return ['processing', 'cancelled'];
      case 'processing':
        return ['shipped', 'cancelled'];
      case 'shipped':
        return ['completed'];
      default:
        return [];
    }
  }

  Future<void> _changeStatus(Order order, String target) async {
    try {
      await context.read<ApiClient>().updateOrderStatus(order.id, target);
      if (!mounted) return;
      showSnack(
        context,
        '${order.orderNumber} -> ${AppTheme.statusLabel(target)}',
      );
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  /// Simulasi pembayaran (admin): order pending -> paid lewat jalur
  /// webhook yang sama. Dipakai saat pelanggan sudah bayar di kasir.
  Future<void> _simulatePayment(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SIMULASI BAYAR?'),
        content: Text(
          'Tandai ${order.orderNumber} (${formatRupiah(order.total)}) '
          'sebagai LUNAS? Status berubah menjadi PAID.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YA, LUNAS'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<ApiClient>().simulatePayment(order.id);
      if (!mounted) return;
      showSnack(context, '${order.orderNumber} lunas (PAID)');
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  /// Label tombol aksi cepat sesuai alur dapur.
  String _actionLabel(String current, String target) {
    if (current == 'paid' && target == 'processing') {
      return 'TERIMA & PROSES';
    }
    if (current == 'shipped' && target == 'completed') {
      return 'SELESAIKAN PESANAN';
    }
    return '→ ${AppTheme.statusLabel(target)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BrutalChip(
                      label: 'Semua',
                      selected: _statusFilter == null,
                      onTap: () {
                        setState(() => _statusFilter = null);
                        _load(reset: true);
                      },
                    ),
                  ),
                  for (final s in _statuses)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: BrutalChip(
                        label: AppTheme.statusLabel(s),
                        selected: _statusFilter == s,
                        onTap: () {
                          setState(() => _statusFilter = s);
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
                        title: 'Gagal memuat pesanan',
                        subtitle: _error!,
                      )
                    : _orders.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long,
                            title: 'Tidak ada pesanan',
                            subtitle: 'Coba filter lain.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            color: AppTheme.borderOf(context),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length + 1,
                              itemBuilder: (context, i) {
                                if (i == _orders.length) {
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
                                final order = _orders[i];
                                final next = _nextStatuses(order.status);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: BrutalCard(
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => OrderDetailScreen(
                                            orderId: order.id,
                                          ),
                                        ),
                                      );
                                      _load(reset: true);
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                order.orderNumber,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            StatusBadge(status: order.status),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${order.orderTypeLabel} • ${order.items.length} item • ${order.shippingName} • ${formatTanggal(order.createdAt)}',
                                          style: TextStyle(
                                            color: AppTheme.mutedOf(context),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (order.processedByName.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Diproses oleh: ${order.processedByName}',
                                              style: TextStyle(
                                                color:
                                                    AppTheme.mutedOf(context),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatRupiah(order.total),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (order.status == 'pending') ...[
                                          const SizedBox(height: 10),
                                          BrutalButton(
                                            label: 'SIMULASI BAYAR (LUNAS)',
                                            primary: false,
                                            onPressed: () =>
                                                _simulatePayment(order),
                                          ),
                                        ],
                                        if (next.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            children: next
                                                .map(
                                                  (s) => GestureDetector(
                                                    onTap: () => _changeStatus(
                                                      order,
                                                      s,
                                                    ),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .statusColor(s),
                                                        border: Border.all(
                                                          color: AppTheme
                                                              .pureBlack,
                                                          width: 2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(2),
                                                      ),
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                      child: Text(
                                                        _actionLabel(
                                                          order.status,
                                                          s,
                                                        ),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 11,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
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
