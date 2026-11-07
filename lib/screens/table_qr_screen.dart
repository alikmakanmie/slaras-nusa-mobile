import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../staff_helpers.dart';
import '../theme.dart';
import '../widgets.dart';

/// QR Code Meja 01–20 -> https://alikmakanmie.my.id/?table=NN.
/// Pelanggan scan -> web membuka mode Dine-In meja tersebut.
class TableQrScreen extends StatelessWidget {
  const TableQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR CODE MEJA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Cetak semua QR meja',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _PrintAllQrScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: BrutalButton(
              label: 'CETAK SEMUA QR MEJA',
              icon: Icons.print,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _PrintAllQrScreen(),
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: 20,
              itemBuilder: (context, i) => _TableQrCard(table: i + 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu kartu QR meja bergaya BoldKit.
class _TableQrCard extends StatelessWidget {
  final int table;

  const _TableQrCard({required this.table});

  @override
  Widget build(BuildContext context) {
    final url = tableQrUrl(table);
    final label = table.toString().padLeft(2, '0');
    return BrutalCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SLARAS NUSA FOODLAB',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.pureBlack, width: 2),
            ),
            padding: const EdgeInsets.all(6),
            child: QrImageView(
              data: url,
              size: 120,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'SCAN UNTUK PESAN\nDI MEJA INI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MEJA $label',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
              showSnack(context, 'Link meja $label disalin');
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderOf(context), width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: const Text(
                'SALIN LINK',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Halaman "cetak semua": 20 kartu QR dalam satu scroll panjang.
/// Cetak lewat screenshot / print sistem Android (tanpa package print).
class _PrintAllQrScreen extends StatelessWidget {
  const _PrintAllQrScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CETAK — SEMUA QR MEJA')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const BrutalCard(
              child: Text(
                'TANGKAP LAYAR / PRINT SISTEM HALAMAN INI UNTUK MENCETAK '
                'SEMUA QR MEJA 01–20.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 1; i <= 20; i++) ...[
              _TableQrCard(table: i),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
