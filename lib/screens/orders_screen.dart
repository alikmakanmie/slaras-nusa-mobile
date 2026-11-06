import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

/// Riwayat pesanan pengguna (dengan tombol batalkan order).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
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
      final result = await context.read<ApiClient>().listOrders(
            page: _page,
            limit: 20,
          );
      if (!mounted) return;
      setState(() {
        _totalPages = result.totalPages;
        _orders = reset ? result.items : [..._orders, ...result.items];
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

  Future<void> _cancel(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BATALKAN ORDER?'),
        content: Text('Batalkan order ${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('TIDAK'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YA, BATALKAN'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await context.read<ApiClient>().cancelOrder(order.id);
      if (!mounted) return;
      showSnack(context, 'Order ${order.orderNumber} dibatalkan');
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PESANAN SAYA')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Gagal memuat pesanan',
                  subtitle: _error!,
                )
              : _orders.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long,
                      title: 'Belum ada pesanan',
                      subtitle: 'Pesananmu akan tampil di sini.',
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    '${order.items.length} item • ${formatTanggal(order.createdAt)}',
                                    style: TextStyle(
                                      color: AppTheme.mutedOf(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatRupiah(order.total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (order.canCancel)
                                        GestureDetector(
                                          onTap: () => _cancel(order),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppTheme.badRed,
                                              border: Border.all(
                                                color: AppTheme.pureBlack,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            child: const Text(
                                              'BATALKAN',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
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
    );
  }
}
