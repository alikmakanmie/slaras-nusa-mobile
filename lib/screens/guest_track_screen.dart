import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Lacak pesanan tamu (publik, tanpa login):
/// GET /orders/track/:order_number -> status + item + total.
///
/// Menampilkan juga "Pesanan Saya": nomor order tamu yang tersimpan
/// di perangkat, bisa diketuk untuk melacak ulang.
class GuestTrackScreen extends StatefulWidget {
  final String? initialOrderNumber;

  const GuestTrackScreen({super.key, this.initialOrderNumber});

  @override
  State<GuestTrackScreen> createState() => _GuestTrackScreenState();
}

class _GuestTrackScreenState extends State<GuestTrackScreen> {
  final _numberController = TextEditingController();
  Order? _order;
  bool _loading = false;
  String? _error;

  static const _steps = [
    'pending',
    'paid',
    'processing',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialOrderNumber != null &&
        widget.initialOrderNumber!.isNotEmpty) {
      _numberController.text = widget.initialOrderNumber!;
      _track();
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _track([String? number]) async {
    final orderNumber = (number ?? _numberController.text).trim();
    if (orderNumber.isEmpty) {
      setState(() => _error = 'Masukkan nomor order dulu');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order =
          await context.read<ApiClient>().trackOrder(orderNumber);
      if (!mounted) return;
      setState(() => _order = order);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _order = null;
        _error = e.statusCode == 404
            ? 'Order $orderNumber tidak ditemukan, atau endpoint track belum aktif di backend (404).'
            : e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<GuestOrdersState>().orders;
    return Scaffold(
      appBar: AppBar(title: const Text('LACAK PESANAN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalTextField(
              controller: _numberController,
              label: 'NOMOR ORDER',
              hint: 'mis. ORD-20261106-XXXXXX',
              onSubmitted: (_) => _track(),
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: _loading ? 'MELACAK...' : 'LACAK PESANAN',
              icon: Icons.search,
              loading: _loading,
              onPressed: _loading ? null : () => _track(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.badRed.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.badRed, width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (_order != null) ...[
              const SizedBox(height: 18),
              _ReceiptCard(order: _order!),
            ],
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionTitle(title: 'PESANAN SAYA (TAMU)'),
              const SizedBox(height: 8),
              for (final entry in saved)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BrutalCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _numberController.text = entry.orderNumber;
                              _track(entry.orderNumber);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.orderNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Disimpan: ${formatTanggal(entry.savedAt)}',
                                  style: TextStyle(
                                    color: AppTheme.mutedOf(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.badRed,
                          ),
                          onPressed: () => context
                              .read<GuestOrdersState>()
                              .remove(entry.orderNumber),
                          tooltip: 'Hapus dari daftar',
                        ),
                      ],
                    ),
                  ),
                ),
            ] else if (_order == null) ...[
              const SizedBox(height: 22),
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada pesanan tersimpan',
                subtitle:
                    'Checkout sebagai tamu, lalu nomor ordermu tersimpan di sini dan bisa dilacak kapan saja.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Struk digital + timeline status order tamu.
class _ReceiptCard extends StatelessWidget {
  final Order order;

  const _ReceiptCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final currentIndex = _GuestTrackScreenState._steps.indexOf(order.status);
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STRUK DIGITAL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.orderNumber,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dibuat: ${formatTanggal(order.createdAt)}',
            style: TextStyle(
              color: AppTheme.mutedOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (order.shippingName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Pemesan: ${order.shippingName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (order.shippingAddressText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              order.shippingAddressText,
              style: TextStyle(
                color: AppTheme.mutedOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Divider(thickness: 2, height: 24),
          // Timeline status.
          for (var i = 0; i < _GuestTrackScreenState._steps.length; i++)
            _step(
              context,
              label: _GuestTrackScreenState._steps[i].toUpperCase(),
              done: currentIndex >= 0 && i <= currentIndex,
              active: i == currentIndex,
              last: i == _GuestTrackScreenState._steps.length - 1,
            ),
          const Divider(thickness: 2, height: 24),
          for (final item in order.items) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${item.productName} x${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatRupiah(item.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const Divider(thickness: 2, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SUBTOTAL',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              Text(
                formatRupiah(order.subtotal),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL BAYAR',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                formatRupiah(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (order.paymentMethod.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Metode: ${order.paymentMethod.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required String label,
    required bool done,
    required bool active,
    required bool last,
  }) {
    final color = done
        ? AppTheme.okGreen
        : AppTheme.mutedOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? AppTheme.okGreen : Colors.transparent,
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!last)
              Container(width: 2, height: 14, color: color),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              color: done
                  ? AppTheme.borderOf(context)
                  : AppTheme.mutedOf(context),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}
