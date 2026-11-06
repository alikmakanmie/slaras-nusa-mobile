import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'checkout_screen.dart';
import 'guest_checkout_screen.dart';

/// Floating Cart Bar — bar mengambang persisten di bawah layar katalog,
/// muncul begitu keranjang berisi minimal 1 item (tamu maupun member).
///
/// BoldKit Neobrutalism: hitam pekat, border tebal, hard shadow, font tebal.
/// Isi: badge jumlah item, daftar singkat nama menu, total harga,
/// tombol "LIHAT / EDIT KERANJANG" (sheet edit tanpa pindah halaman)
/// dan tombol utama "CHECKOUT SEKARANG →" (langsung ke alur checkout).
class FloatingCartBar extends StatelessWidget {
  const FloatingCartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final count = cart.totalItems;
    if (count <= 0) return const SizedBox.shrink();

    final lines = cart.cartLines;
    final names = lines.map((l) => l.name).toList();
    final shown = names.take(2).join(', ');
    final extra = names.length > 2 ? ' +${names.length - 2} lagi' : '';
    final namesText = '$shown$extra';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureBlack,
        border: Border.all(color: AppTheme.borderOf(context), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowOf(context),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.white),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Text(
                  '[ $count ITEM ]',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  namesText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRupiah(cart.subtotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => showCartEditSheet(context),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: const Text(
                      'LIHAT / EDIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => goToCheckout(context),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: const Text(
                      'CHECKOUT SEKARANG →',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Langsung ke alur checkout dalam 1 klik:
/// tamu -> GuestCheckoutScreen, member -> CheckoutScreen.
void goToCheckout(BuildContext context) {
  final isLoggedIn = context.read<AuthState>().isLoggedIn;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          isLoggedIn ? const CheckoutScreen() : const GuestCheckoutScreen(),
    ),
  );
}

/// Sheet edit keranjang (drawer/modal): ubah qty +/-, hapus item,
/// tanpa pindah halaman. Tamu edit keranjang lokal, member edit /cart.
Future<void> showCartEditSheet(BuildContext outerContext) {
  return showModalBottomSheet<void>(
    context: outerContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _CartEditSheet(
        onCheckout: () {
          Navigator.of(sheetContext).pop();
          goToCheckout(outerContext);
        },
      );
    },
  );
}

class _CartEditSheet extends StatelessWidget {
  final VoidCallback onCheckout;

  const _CartEditSheet({required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final lines = cart.cartLines;
    final isMember = cart.isMemberCart;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(
          top: BorderSide(color: AppTheme.borderOf(context), width: 2),
          left: BorderSide(color: AppTheme.borderOf(context), width: 2),
          right: BorderSide(color: AppTheme.borderOf(context), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowOf(context),
            offset: const Offset(0, -4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'KERANJANG',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.pureBlack,
                  border: Border.all(
                    color: AppTheme.borderOf(context),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Text(
                  isMember ? 'MEMBER' : 'MODE TAMU',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Tutup',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Keranjang masih kosong',
                subtitle: 'Tambah menu dari katalog dulu.',
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _CartLineRow(line: lines[i]),
              ),
            ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  formatRupiah(cart.subtotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BrutalButton(
              label: 'CHECKOUT SEKARANG →',
              onPressed: onCheckout,
            ),
          ],
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  final CartLine line;

  const _CartLineRow({required this.line});

  Future<void> _setQty(BuildContext context, int qty) async {
    try {
      await context.read<CartState>().setLineQty(line, qty);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _remove(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS ITEM?'),
        content: Text('Hapus "${line.name}" dari keranjang?'),
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
    if (confirm != true || !context.mounted) return;
    try {
      await context.read<CartState>().removeLine(line);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatRupiah(line.price)} × ${line.quantity} = ${formatRupiah(line.subtotal)}',
                  style: TextStyle(
                    color: AppTheme.mutedOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          QtyStepper(
            value: line.quantity,
            onChanged: (qty) => _setQty(context, qty),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: AppTheme.badRed,
            onPressed: () => _remove(context),
            tooltip: 'Hapus item',
          ),
        ],
      ),
    );
  }
}
