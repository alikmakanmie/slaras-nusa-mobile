import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../staff_helpers.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Detail order (staf): timeline status, item, alamat, pembayaran +
/// simulasi bayar & batalkan via endpoint admin.
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  static const _flow = [
    'pending',
    'paid',
    'processing',
    'shipped',
    'completed',
  ];
  static const _flowLabels = {
    'pending': 'Pesanan dibuat',
    'paid': 'Pembayaran diterima',
    'processing': 'Pesanan diproses',
    'shipped': 'Pesanan dikirim',
    'completed': 'Pesanan selesai',
  };

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
      final order = await context.read<ApiClient>().getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
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

  Future<void> _simulatePayment() async {
    final order = _order;
    if (order == null) return;
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
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _showReceipt() async {
    final order = _order;
    if (order == null) return;
    final cashier = context.read<AuthState>().user?.name;
    final text = receiptText(order, cashierName: cashier);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('STRUK THERMAL'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.of(context).pop();
              showSnack(context, 'Struk disalin — tempel ke printer/WA');
            },
            child: const Text('SALIN STRUK'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    final order = _order;
    if (order == null) return;
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
      await context
          .read<ApiClient>()
          .updateOrderStatus(order.id, 'cancelled');
      if (!mounted) return;
      showSnack(context, 'Order dibatalkan');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DETAIL ORDER'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null || order == null
              ? EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Gagal memuat order',
                  subtitle: _error ?? 'Order tidak ditemukan.',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BrutalCard(
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
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                StatusBadge(status: order.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jenis: ${order.orderTypeLabel}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (order.processedByName.isNotEmpty)
                              Text(
                                'Diproses oleh: ${order.processedByName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            Text(
                              'Dibuat: ${formatTanggal(order.createdAt)}',
                              style: TextStyle(
                                color: AppTheme.mutedOf(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Metode: ${order.paymentMethod.toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (order.notes.isNotEmpty)
                              Text(
                                'Catatan: ${order.notes}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionTitle(title: 'Lacak Pesanan'),
                      const SizedBox(height: 10),
                      BrutalCard(child: _buildTimeline(order)),
                      const SizedBox(height: 18),
                      const SectionTitle(title: 'Item Pesanan'),
                      const SizedBox(height: 10),
                      BrutalCard(
                        child: Column(
                          children: [
                            for (final item in order.items)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item.productName} x${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          formatRupiah(item.subtotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.modifiersLabel.isNotEmpty)
                                      Text(
                                        '+ ${item.modifiersLabel}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (item.notes.isNotEmpty)
                                      Text(
                                        '* ${item.notes}',
                                        style: TextStyle(
                                          color: AppTheme.mutedOf(context),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const Divider(thickness: 2, height: 18),
                            _totalRow('Subtotal', order.subtotal),
                            if (order.voucherCode.isNotEmpty)
                              _totalRow(
                                'Voucher ${order.voucherCode}',
                                -order.discountAmount,
                              ),
                            _totalRow('Ongkir', order.shippingCost),
                            _totalRow('TOTAL', order.total, bold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionTitle(title: 'Alamat Pengiriman'),
                      const SizedBox(height: 10),
                      BrutalCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.shippingName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              order.shippingPhone,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              order.shippingAddressText,
                              style: TextStyle(
                                color: AppTheme.mutedOf(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (order.payment != null) ...[
                        const SizedBox(height: 18),
                        const SectionTitle(title: 'Pembayaran'),
                        const SizedBox(height: 10),
                        BrutalCard(
                          child: Column(
                            children: [
                              _totalRow(
                                'Status Bayar',
                                0,
                                valueText: AppTheme.statusLabel(
                                  order.payment!.status,
                                ),
                              ),
                              _totalRow(
                                'ID Transaksi',
                                0,
                                valueText: order.payment!.transactionId,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      BrutalButton(
                        label: 'CETAK STRUK',
                        icon: Icons.print,
                        onPressed: _showReceipt,
                      ),
                      const SizedBox(height: 12),
                      if (order.status == 'pending' &&
                          order.payment != null)
                        BrutalButton(
                          label: 'SIMULASI BAYAR (LUNAS)',
                          icon: Icons.payment,
                          onPressed: _simulatePayment,
                        ),
                      if (order.status == 'pending' ||
                          order.status == 'paid' ||
                          order.status == 'processing') ...[
                        const SizedBox(height: 12),
                        BrutalButton(
                          label: 'BATALKAN ORDER',
                          primary: false,
                          icon: Icons.cancel,
                          onPressed: _cancel,
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _totalRow(String label, int value,
      {bool bold = false, String? valueText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 16 : 14,
            ),
          ),
          Text(
            valueText ?? formatRupiah(value),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: bold ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Order order) {
    if (order.status == 'cancelled') {
      return Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.badRed,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ORDER DIBATALKAN',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    }
    final currentIndex = _flow.indexOf(order.status);
    final reached = currentIndex < 0 ? 0 : currentIndex;
    return Column(
      children: List.generate(_flow.length, (i) {
        final done = i <= reached;
        final isLast = i == _flow.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: done ? AppTheme.okGreen : Colors.transparent,
                    border: Border.all(
                      color: AppTheme.borderOf(context),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Icon(
                    done ? Icons.check : Icons.circle_outlined,
                    color: done ? Colors.white : AppTheme.mutedOf(context),
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 22,
                    color: done
                        ? AppTheme.okGreen
                        : AppTheme.mutedOf(context).withValues(alpha: 0.4),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _flowLabels[_flow[i]]!.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                    color: done
                        ? Theme.of(context).colorScheme.onSurface
                        : AppTheme.mutedOf(context),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
