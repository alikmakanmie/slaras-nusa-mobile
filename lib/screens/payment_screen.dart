import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'guest_track_screen.dart';
import 'order_detail_screen.dart';

/// Halaman pembayaran mock gateway.
///
/// Alur simulasi (sesuai yang disediakan backend):
/// 1. Tampilkan payment_url / QRIS dari order.payment.
/// 2. Tombol "Simulasikan Pembayaran" membuka payment_url (halaman MockPay)
///    lalu mem-poll GET /orders/:id setiap 2 detik sampai status jadi paid.
/// 3. Status order HANYA berubah lewat webhook gateway (HMAC, server-side)
///    — aplikasi TIDAK PERNAH memanggil webhook langsung (WEBHOOK_SECRET
///    tidak boleh ada di klien). Bila polling habis waktu, layar menjelaskan
///    hal ini dan menyediakan tombol cek status manual.
class PaymentScreen extends StatefulWidget {
  final Order order;

  /// true bila order berasal dari guest checkout: polling status memakai
  /// endpoint publik /orders/track/:order_number (tanpa JWT).
  final bool isGuest;

  const PaymentScreen({super.key, required this.order, this.isGuest = false});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Order _order;
  Timer? _pollTimer;
  bool _polling = false;
  bool _opening = false;
  String? _pollNote;
  int _pollCount = 0;

  static const _maxPolls = 45; // 45 x 2 detik = 90 detik.

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    try {
      final fresh = widget.isGuest
          ? await context.read<ApiClient>().trackOrder(_order.orderNumber)
          : await context.read<ApiClient>().getOrder(_order.id);
      if (!mounted) return;
      setState(() => _order = fresh);
      if (fresh.status == 'paid') _stopPolling(success: true);
    } catch (_) {
      // Abaikan error sesekali saat polling; coba lagi di tick berikutnya.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    setState(() {
      _polling = true;
      _pollNote = 'Menunggu konfirmasi pembayaran...';
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      _pollCount++;
      await _refreshOrder();
      if (!mounted) return;
      if (_order.status == 'paid') return; // _refreshOrder sudah stop.
      if (_pollCount >= _maxPolls) {
        _stopPolling(success: false);
      }
    });
  }

  void _stopPolling({required bool success}) {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _polling = false;
      _pollNote = success
          ? 'Pembayaran terkonfirmasi! Status order: DIBAYAR.'
          : 'Waktu tunggu habis — status masih ${_order.status.toUpperCase()}. '
              'Pembayaran mock hanya berubah lewat webhook gateway '
              '(server-side). Coba lagi atau cek status manual.';
    });
    if (success) {
      showSnack(context, 'Pembayaran berhasil! Order dibayar.');
    }
  }

  Future<void> _openPaymentPage() async {
    final url = _order.payment?.paymentUrl;
    if (url == null || url.isEmpty) {
      showSnack(context, 'Payment URL tidak tersedia', isError: true);
      return;
    }
    setState(() => _opening = true);
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showSnack(context, 'Tidak bisa membuka halaman bayar', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Gagal membuka halaman: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Tombol simulasi: buka halaman mock-pay, lalu poll status order.
  Future<void> _simulatePayment() async {
    await _openPaymentPage();
    if (!mounted) return;
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final payment = _order.payment;
    final isQris = _order.paymentMethod.toLowerCase().contains('qris');
    final paid = _order.status == 'paid';
    return Scaffold(
      appBar: AppBar(title: const Text('PEMBAYARAN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ORDER',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      StatusBadge(status: _order.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _order.orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dibuat: ${formatTanggal(_order.createdAt)}',
                    style: TextStyle(
                      color: AppTheme.mutedOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(thickness: 2, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL BAYAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        formatRupiah(_order.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Metode: ${_order.paymentMethod.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (payment != null && isQris && payment.qrString.isNotEmpty)
              BrutalCard(
                child: Column(
                  children: [
                    const Text(
                      'SCAN QRIS UNTUK MEMBAYAR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: AppTheme.pureBlack,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: payment.qrString,
                        version: QrVersions.auto,
                        size: 210,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      payment.qrString,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.mutedOf(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else if (payment != null)
              BrutalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VIRTUAL ACCOUNT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bayar melalui halaman mock gateway dengan menekan tombol di bawah, lalu simulasikan pembayaran.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (payment.transactionId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        'ID Transaksi: ${payment.transactionId}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 18),
            BrutalButton(
              label: 'BUKA HALAMAN PEMBAYARAN',
              icon: Icons.open_in_browser,
              primary: false,
              loading: _opening,
              onPressed: _opening ? null : _openPaymentPage,
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: paid
                  ? 'SUDAH DIBAYAR'
                  : (_polling ? 'MENUNGGU PEMBAYARAN...' : 'SIMULASIKAN PEMBAYARAN SUKSES'),
              icon: Icons.check_circle,
              loading: _polling,
              onPressed: paid || _polling ? null : _simulatePayment,
            ),
            if (_pollNote != null) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: paid
                      ? AppTheme.okGreen.withValues(alpha: 0.12)
                      : AppTheme.warnAmber.withValues(alpha: 0.12),
                  border: Border.all(
                    color: paid ? AppTheme.okGreen : AppTheme.warnAmber,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  _pollNote!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 12),
            BrutalButton(
              label: 'CEK STATUS ORDER',
              primary: false,
              icon: Icons.refresh,
              onPressed: _refreshOrder,
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: widget.isGuest
                  ? 'LIHAT STATUS / STRUK'
                  : 'LIHAT DETAIL ORDER',
              primary: false,
              icon: Icons.receipt_long,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => widget.isGuest
                        ? GuestTrackScreen(
                            initialOrderNumber: _order.orderNumber,
                          )
                        : OrderDetailScreen(orderId: _order.id),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Catatan: gateway ini adalah mock. Status berubah menjadi DIBAYAR setelah webhook gateway diterima server (bukan dari aplikasi).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedOf(context),
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
