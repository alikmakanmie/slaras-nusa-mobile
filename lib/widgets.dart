import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';
import 'utils.dart';

/// Widget-widget Neobrutalism yang dipakai di semua layar.

/// Tombol brutal: border tebal + hard shadow, efek tekan
/// (geser 2px + shadow hilang) saat ditekan.
class BrutalButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expanded;
  final bool loading;

  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expanded = true,
    this.loading = false,
  });

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.loading;
    final bg = widget.primary
        ? (isDark ? Colors.white : AppTheme.pureBlack)
        : AppTheme.surfaceOf(context);
    final fg = widget.primary
        ? (isDark ? AppTheme.pureBlack : Colors.white)
        : Theme.of(context).colorScheme.onSurface;
    final shadow = _pressed || !enabled
        ? <BoxShadow>[]
        : [
            BoxShadow(
              color: AppTheme.shadowOf(context),
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ];
    final child = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: fg,
            ),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(
        _pressed ? 2.0 : 0.0,
        _pressed ? 2.0 : 0.0,
        0.0,
      ),
      decoration: BoxDecoration(
        color: enabled ? bg : bg.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.borderOf(context), width: 2),
        borderRadius: BorderRadius.circular(2),
        boxShadow: shadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: child,
    );
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: enabled ? widget.onPressed : null,
      child: widget.expanded
          ? SizedBox(width: double.infinity, child: box)
          : box,
    );
  }
}

/// Card brutal dengan border tebal + hard shadow.
class BrutalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double shadowSize;

  const BrutalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.shadowSize = 4,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: AppTheme.brutalCard(context, size: shadowSize),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        child: card,
      ),
    );
  }
}

/// Text field brutal.
class BrutalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;
  final Widget? prefix;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const BrutalTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.prefix,
    this.validator,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        hintText: hint,
        suffixIcon: suffix,
        prefixIcon: prefix,
      ),
    );
  }
}

/// Chip kategori brutal (bisa dipilih).
class BrutalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const BrutalChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? (isDark ? Colors.white : AppTheme.pureBlack)
        : AppTheme.surfaceOf(context);
    final fg = selected
        ? (isDark ? AppTheme.pureBlack : Colors.white)
        : Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: AppTheme.borderOf(context), width: 2),
          borderRadius: BorderRadius.circular(2),
          boxShadow: selected
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.shadowOf(context),
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Badge status brutal (isi warna solid, teks putih/hitam tebal).
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppTheme.pureBlack, width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        AppTheme.statusLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Gambar produk: URL absolut/relatif; bila URL kosong atau gambar gagal
/// dimuat, tampilkan placeholder BoldKit hitam-putih bertuliskan nama menu.
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final String fallbackName;
  final double height;
  final double? width;

  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.fallbackName,
    this.height = 140,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.resolveImageUrl(imageUrl);
    final name = fallbackName.trim().isEmpty
        ? 'SLARAS'
        : fallbackName.trim().toUpperCase();
    // Ukuran font nama mengikuti tinggi tile agar tetap terbaca.
    final fontSize = height >= 200
        ? 20.0
        : height >= 100
            ? 13.0
            : 11.0;
    final placeholder = Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.pureBlack,
        border: Border.all(color: AppTheme.borderOf(context), width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          height: 1.2,
        ),
      ),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      height: height,
      width: width ?? double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: height,
          width: width ?? double.infinity,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        );
      },
    );
  }
}

/// Stepper kuantitas brutal (+ / -).
class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
  });

  @override
  Widget build(BuildContext context) {
    Widget stepButton(IconData icon, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: onTap == null
                ? AppTheme.mutedOf(context).withValues(alpha: 0.25)
                : AppTheme.surfaceOf(context),
            border: Border.all(color: AppTheme.borderOf(context), width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(icon, size: 18),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stepButton(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        Container(
          width: 44,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.borderOf(context), width: 2),
              bottom: BorderSide(color: AppTheme.borderOf(context), width: 2),
            ),
          ),
          child: Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
        stepButton(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

/// Judul seksi brutal.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.0,
                decoration: TextDecoration.underline,
                decorationThickness: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: AppTheme.brutalCard(context),
              padding: const EdgeInsets.all(18),
              child: Icon(icon, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? AppTheme.badRed
          : (Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : AppTheme.pureBlack),
    ),
  );
}

String formatRupiahShort(int value) => formatRupiah(value);
