import 'package:flutter/material.dart';

/// Design system Neobrutalism BoldKit — seragam dengan versi web.
///
/// Light: background #F4F4F0, hitam pekat #000000 dominan.
/// Dark: background #09090B, card karbon #121215, aksen putih monokrom.
/// Ciri: border hitam tebal, sudut tajam (radius kecil), hard offset shadow,
/// tipografi tebal uppercase.
class AppTheme {
  static const Color boneWhite = Color(0xFFF4F4F0);
  static const Color pureBlack = Color(0xFF000000);
  static const Color darkBg = Color(0xFF09090B);
  static const Color darkCard = Color(0xFF121215);
  static const Color darkBorder = Color(0xFFFFFFFF);
  static const Color mutedLight = Color(0xFF55534E);
  static const Color mutedDark = Color(0xFFA1A1AA);

  // Warna status (fungsional, tetap brutal: isi solid + border hitam).
  static const Color okGreen = Color(0xFF16A34A);
  static const Color warnAmber = Color(0xFFF59E0B);
  static const Color badRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF2563EB);

  static ThemeData light() {
    const ink = pureBlack;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: boneWhite,
      colorScheme: const ColorScheme.light(
        primary: pureBlack,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: boneWhite,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        displayMedium: TextStyle(fontWeight: FontWeight.w900, color: ink),
        displaySmall: TextStyle(fontWeight: FontWeight.w900, color: ink),
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        headlineMedium: TextStyle(fontWeight: FontWeight.w900, color: ink),
        headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
        titleSmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
        bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: ink),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: ink),
        bodySmall: TextStyle(fontWeight: FontWeight.w500, color: ink),
        labelLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: pureBlack, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: pureBlack, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: pureBlack, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: badRed, width: 2),
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: mutedLight,
          letterSpacing: 0.8,
        ),
        hintStyle: const TextStyle(color: mutedLight),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: pureBlack,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: pureBlack,
    );
  }

  static ThemeData dark() {
    const ink = Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: pureBlack,
        surface: darkCard,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        displayMedium: TextStyle(fontWeight: FontWeight.w900, color: ink),
        displaySmall: TextStyle(fontWeight: FontWeight.w900, color: ink),
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        headlineMedium: TextStyle(fontWeight: FontWeight.w900, color: ink),
        headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
        titleSmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
        bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: ink),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: ink),
        bodySmall: TextStyle(fontWeight: FontWeight.w500, color: ink),
        labelLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: Colors.white, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: badRed, width: 2),
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: mutedDark,
          letterSpacing: 0.8,
        ),
        hintStyle: const TextStyle(color: mutedDark),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: TextStyle(
          color: pureBlack,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: Colors.white,
    );
  }

  /// Warna border tegas sesuai mode.
  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : pureBlack;

  /// Warna hard shadow sesuai mode.
  static Color shadowOf(BuildContext context) => borderOf(context);

  /// Warna permukaan card sesuai mode.
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCard
          : Colors.white;

  /// Warna teks sekunder sesuai mode.
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? mutedDark
          : mutedLight;

  /// Dekorasi card brutal: border tebal + hard offset shadow.
  static BoxDecoration brutalCard(BuildContext context, {double size = 4}) {
    return BoxDecoration(
      color: surfaceOf(context),
      border: Border.all(color: borderOf(context), width: 2),
      borderRadius: BorderRadius.circular(2),
      boxShadow: [
        BoxShadow(
          color: shadowOf(context),
          offset: Offset(size, size),
          blurRadius: 0,
        ),
      ],
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'paid':
      case 'completed':
      case 'settlement':
        return okGreen;
      case 'pending':
        return warnAmber;
      case 'processing':
      case 'shipped':
        return infoBlue;
      case 'cancelled':
      case 'failed':
      case 'expire':
      case 'cancel':
        return badRed;
      default:
        return mutedLight;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'MENUNGGU BAYAR';
      case 'paid':
        return 'DIBAYAR';
      case 'processing':
        return 'DIPROSES';
      case 'shipped':
        return 'DIKIRIM';
      case 'completed':
        return 'SELESAI';
      case 'cancelled':
        return 'DIBATALKAN';
      case 'settlement':
        return 'LUNAS';
      case 'expire':
        return 'KEDALUWARSA';
      case 'failed':
        return 'GAGAL';
      case 'cancel':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }
}
