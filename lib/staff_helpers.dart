import 'models.dart';
import 'utils.dart';

/// Helper murni (tanpa dependensi Flutter) untuk fitur staf:
/// URL QR meja + teks struk thermal.

/// URL web pelanggan untuk satu meja, mis. meja 5 -> .../?table=05.
String tableQrUrl(int tableNumber) {
  final n = tableNumber.toString().padLeft(2, '0');
  return 'https://alikmakanmie.my.id/?table=$n';
}

/// Daftar URL QR Meja 01 s/d Meja 20.
List<String> allTableQrUrls() =>
    List.generate(20, (i) => tableQrUrl(i + 1));

/// Teks struk kasir (58mm/80mm) untuk satu order — dipakai dialog
/// "CETAK STRUK" di antrean dapur & detail order (salin ke clipboard).
String receiptText(Order order, {String? cashierName}) {
  final b = StringBuffer();
  b.writeln('SLARAS NUSA FOODLAB');
  b.writeln('Coffee Shop & Foodlab');
  b.writeln('================================');
  b.writeln('No Order : ${order.orderNumber}');
  b.writeln('Jenis    : ${order.orderTypeLabel}');
  b.writeln('Pelanggan: ${order.shippingName}');
  if (order.shippingPhone.isNotEmpty) {
    b.writeln('WA       : ${order.shippingPhone}');
  }
  b.writeln('Waktu    : ${formatTanggal(order.createdAt)}');
  b.writeln('--------------------------------');
  for (final item in order.items) {
    b.writeln(
      '${item.productName} x${item.quantity}  ${formatRupiah(item.subtotal)}',
    );
    if (item.modifiersLabel.isNotEmpty) {
      b.writeln('  + ${item.modifiersLabel}');
    }
    if (item.notes.isNotEmpty) b.writeln('  * ${item.notes}');
  }
  b.writeln('--------------------------------');
  b.writeln('Subtotal : ${formatRupiah(order.subtotal)}');
  if (order.voucherCode.isNotEmpty) {
    b.writeln('Voucher ${order.voucherCode}: -${formatRupiah(order.discountAmount)}');
  }
  if (order.shippingCost > 0) {
    b.writeln('Ongkir   : ${formatRupiah(order.shippingCost)}');
  }
  b.writeln('TOTAL    : ${formatRupiah(order.total)}');
  b.writeln('Bayar    : ${order.paymentMethod.toUpperCase()}');
  if (order.processedByName.isNotEmpty) {
    b.writeln('Diproses oleh: ${order.processedByName}');
  } else if (cashierName != null && cashierName.isNotEmpty) {
    b.writeln('Kasir    : $cashierName');
  }
  b.writeln('================================');
  b.writeln('Terima kasih! Lacak pesanan di');
  b.writeln('https://alikmakanmie.my.id/track/${order.orderNumber}');
  return b.toString();
}
