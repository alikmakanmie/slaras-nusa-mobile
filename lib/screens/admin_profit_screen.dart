import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Dashboard Profit (admin): ringkasan profit dari
/// GET /admin/analytics/profit?period=today|7d|30d|all.
///
/// KPI: Omzet, Laba Bersih, Margin %, Pesanan Lunas, AOV.
/// Grafik Omzet vs Laba (batang sederhana), menu paling menguntungkan,
/// 10 transaksi terbaru. Bila endpoint belum aktif (404), tampilkan
/// pesan jujur, bukan angka palsu.
class AdminProfitScreen extends StatefulWidget {
  const AdminProfitScreen({super.key});

  @override
  State<AdminProfitScreen> createState() => _AdminProfitScreenState();
}

class _AdminProfitScreenState extends State<AdminProfitScreen> {
  static const _periods = [
    ('today', 'HARI INI'),
    ('7d', '7 HARI'),
    ('30d', '30 HARI'),
    ('all', 'SEMUA'),
  ];

  String _period = 'today';
  ProfitAnalytics? _data;
  bool _loading = true;
  String? _error;

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
      final data = await context
          .read<ApiClient>()
          .getProfitAnalytics(period: _period);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Endpoint analitik profit belum aktif di backend (404).'
            : e.message;
        _loading = false;
      });
    }
  }

  void _setPeriod(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.borderOf(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter periode.
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (value, label) in _periods)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BrutalChip(
                          label: label,
                          selected: _period == value,
                          onTap: () => _setPeriod(value),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else if (_error != null)
                EmptyState(
                  icon: Icons.bar_chart,
                  title: 'Analitik belum tersedia',
                  subtitle: _error!,
                )
              else if (data == null)
                const EmptyState(
                  icon: Icons.bar_chart,
                  title: 'Tidak ada data',
                  subtitle: 'Belum ada transaksi pada periode ini.',
                )
              else ...[
                // Kartu KPI.
                _KpiGrid(summary: data.summary),
                const SizedBox(height: 10),
                BrutalCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniStat(
                        'TOTAL HPP',
                        formatRupiah(data.summary.totalCogs),
                      ),
                      _miniStat(
                        'PENDING / BATAL',
                        '${data.summary.pendingOrCancelledCount}',
                      ),
                      _miniStat(
                        'PERIODE',
                        data.startDate == data.endDate
                            ? data.startDate
                            : '${data.startDate} s.d. ${data.endDate}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Grafik Omzet vs Laba'),
                const SizedBox(height: 10),
                BrutalCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _legend(AppTheme.pureBlack, 'OMZET'),
                          const SizedBox(width: 16),
                          _legend(AppTheme.okGreen, 'LABA'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (data.dailySeries.isEmpty)
                        const Text(
                          'Belum ada transaksi pada periode ini.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        )
                      else
                        for (final point in data.dailySeries)
                          _DayBars(point: point, maxRevenue: _maxRevenue(data)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Per Jenis Pesanan'),
                const SizedBox(height: 10),
                BrutalCard(
                  child: Column(
                    children: [
                      for (final row in data.byOrderType)
                        _BreakdownRow(
                          label: _orderTypeLabel(row.orderType),
                          count: row.ordersCount,
                          value: row.revenue,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Per Metode Bayar'),
                const SizedBox(height: 10),
                BrutalCard(
                  child: Column(
                    children: [
                      for (final row in data.byPaymentMethod)
                        _BreakdownRow(
                          label: row.paymentMethod.toUpperCase(),
                          count: row.ordersCount,
                          value: row.revenue,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Menu Paling Menguntungkan'),
                const SizedBox(height: 10),
                if (data.topProducts.isEmpty)
                  const EmptyState(
                    icon: Icons.star_outline,
                    title: 'Belum ada penjualan',
                    subtitle: 'Top produk muncul setelah ada order lunas.',
                  )
                else
                  for (var i = 0; i < data.topProducts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BrutalCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.pureBlack,
                                border: Border.all(
                                  color: AppTheme.borderOf(context),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.topProducts[i].productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${data.topProducts[i].quantitySold} terjual',
                                    style: TextStyle(
                                      color: AppTheme.mutedOf(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatRupiah(data.topProducts[i].revenue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Laba ${formatRupiah(data.topProducts[i].profit)}',
                                  style: const TextStyle(
                                    color: AppTheme.okGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Transaksi Terbaru'),
                const SizedBox(height: 10),
                if (data.recentTransactions.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long,
                    title: 'Belum ada transaksi',
                    subtitle: 'Transaksi terbaru muncul di sini.',
                  )
                else
                  for (final tx in data.recentTransactions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BrutalCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tx.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                StatusBadge(status: tx.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx.tableNumber.isEmpty
                                  ? '${tx.customerName} • ${_orderTypeLabel(tx.orderType)}'
                                  : '${tx.customerName} • ${_orderTypeLabel(tx.orderType)} • ${tx.tableNumber}',
                              style: TextStyle(
                                color: AppTheme.mutedOf(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            if (tx.processedByName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Diproses oleh: ${tx.processedByName}',
                                  style: TextStyle(
                                    color: AppTheme.mutedOf(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatTanggal(tx.createdAt),
                                  style: TextStyle(
                                    color: AppTheme.mutedOf(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  formatRupiah(tx.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  int _maxRevenue(ProfitAnalytics data) {
    var max = 0;
    for (final p in data.dailySeries) {
      if (p.revenue > max) max = p.revenue;
    }
    return max <= 0 ? 1 : max;
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedOf(context),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine_in':
        return 'DINE-IN';
      case 'takeaway':
        return 'TAKEAWAY';
      case 'delivery':
        return 'DELIVERY';
      default:
        return type.toUpperCase();
    }
  }
}

class _KpiGrid extends StatelessWidget {
  final ProfitSummary summary;

  const _KpiGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _KpiCard(
          label: 'OMZET',
          value: formatRupiah(summary.grossRevenue),
        ),
        _KpiCard(
          label: 'LABA BERSIH',
          value: formatRupiah(summary.netProfit),
          valueColor: AppTheme.okGreen,
        ),
        _KpiCard(
          label: 'MARGIN',
          value: '${summary.profitMarginPercent.toStringAsFixed(1)}%',
        ),
        _KpiCard(
          label: 'PESANAN LUNAS',
          value: '${summary.totalPaidOrders}',
        ),
        _KpiCard(
          label: 'RATA-RATA ORDER (AOV)',
          value: formatRupiah(summary.averageOrderValue),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _KpiCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedOf(context),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBars extends StatelessWidget {
  final DailyProfitPoint point;
  final int maxRevenue;

  const _DayBars({required this.point, required this.maxRevenue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                point.date,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              Text(
                '${point.ordersCount} order',
                style: TextStyle(
                  color: AppTheme.mutedOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _Bar(
            fraction: point.revenue / maxRevenue,
            color: AppTheme.pureBlack,
            label: formatRupiah(point.revenue),
          ),
          const SizedBox(height: 4),
          _Bar(
            fraction: point.profit / maxRevenue,
            color: AppTheme.okGreen,
            label: formatRupiah(point.profit),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final String label;

  const _Bar({
    required this.fraction,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderOf(context), width: 1),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.02, 1.0),
              child: Container(color: color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int count;
  final int value;

  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            '$count order',
            style: TextStyle(
              color: AppTheme.mutedOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatRupiah(value),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
