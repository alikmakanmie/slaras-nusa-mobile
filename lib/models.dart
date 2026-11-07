import 'dart:convert';

import 'utils.dart';

/// Opsi modifier (varian / add-on) satu produk.
class ModifierOption {
  final String name;
  final int priceDelta; // tambahan harga jual (Rp)
  final int costDelta; // tambahan HPP (Rp)

  const ModifierOption({
    required this.name,
    this.priceDelta = 0,
    this.costDelta = 0,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) =>
      ModifierOption(
        name: parseString(json['name']),
        priceDelta: parseInt(json['price_delta']),
        costDelta: parseInt(json['cost_delta']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price_delta': priceDelta,
        'cost_delta': costDelta,
      };
}

/// Grup modifier, mis. Temperature (single) atau Add-Ons (multi).
class ModifierGroup {
  final String name;
  final String type; // "single" | "multi"
  final List<ModifierOption> options;

  const ModifierGroup({
    required this.name,
    this.type = 'single',
    this.options = const [],
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    final opts = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(ModifierOption.fromJson)
            .toList()
        : <ModifierOption>[];
    return ModifierGroup(
      name: parseString(json['name']),
      type: parseString(json['type'], 'single'),
      options: opts,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'options': options.map((o) => o.toJson()).toList(),
      };
}

/// Modifier bawaan seeder backend untuk produk minuman/makanan.
List<ModifierGroup> defaultModifiers() => const [
      ModifierGroup(name: 'Temperature', type: 'single', options: [
        ModifierOption(name: 'Iced'),
        ModifierOption(name: 'Hot'),
      ]),
      ModifierGroup(name: 'Sugar Level', type: 'single', options: [
        ModifierOption(name: 'Normal Sugar'),
        ModifierOption(name: 'Less Sugar'),
        ModifierOption(name: 'No Sugar'),
      ]),
      ModifierGroup(name: 'Ice Level', type: 'single', options: [
        ModifierOption(name: 'Normal Ice'),
        ModifierOption(name: 'Less Ice'),
      ]),
      ModifierGroup(name: 'Add-Ons', type: 'multi', options: [
        ModifierOption(
          name: 'Extra Espresso Shot',
          priceDelta: 5000,
          costDelta: 2500,
        ),
        ModifierOption(
          name: 'Upgrade Oat Milk',
          priceDelta: 8000,
          costDelta: 4500,
        ),
        ModifierOption(
          name: 'Extra Cheese / Sambal',
          priceDelta: 4000,
          costDelta: 2000,
        ),
      ]),
    ];

/// Model-model domain APLIKASI STAFF, dipetakan dari JSON backend Go
/// (lihat ecommerce-api/internal/domain/*.go).
/// Fitur belanja pelanggan (keranjang/alamat/guest checkout) DIHAPUS —
/// pelanggan memesan lewat website.

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // "admin" | "superadmin" | "customer"
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  /// Admin toko (admin) maupun superadmin boleh mengakses fitur admin
  /// (kelola produk/kategori/pesanan, dashboard profit) — sesuai RBAC
  /// backend: RequireRole(admin, superadmin) untuk operasional toko.
  bool get isAdmin => role == 'admin' || role == 'superadmin';

  bool get isSuperAdmin => role == 'superadmin';

  bool get isCustomer => role == 'customer';

  String get roleLabel => switch (role) {
        'superadmin' => 'SUPERADMIN',
        'admin' => 'ADMIN TOKO',
        _ => 'CUSTOMER',
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: parseString(json['id']),
        name: parseString(json['name']),
        email: parseString(json['email']),
        phone: parseString(json['phone']),
        role: parseString(json['role'], 'customer'),
        isActive: parseBool(json['is_active'], true),
      );

  User copyWith({String? name, String? phone}) => User(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        role: role,
        isActive: isActive,
      );
}

/// Statistik pengguna (superadmin).
/// GET /superadmin/users/stats -> {total, admin, superadmin, customer,
/// inactive, active}.
class UserStats {
  final int total;
  final int admin;
  final int superadmin;
  final int customer;
  final int inactive;
  final int active;

  const UserStats({
    required this.total,
    required this.admin,
    required this.superadmin,
    required this.customer,
    required this.inactive,
    required this.active,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        total: parseInt(json['total']),
        admin: parseInt(json['admin']),
        superadmin: parseInt(json['superadmin']),
        customer: parseInt(json['customer']),
        inactive: parseInt(json['inactive']),
        active: parseInt(json['active']),
      );

  static const empty = UserStats(
    total: 0,
    admin: 0,
    superadmin: 0,
    customer: 0,
    inactive: 0,
    active: 0,
  );
}

class Category {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String imageUrl;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: parseString(json['id']),
        name: parseString(json['name']),
        slug: parseString(json['slug']),
        description: parseString(json['description']),
        imageUrl: parseString(json['image_url']),
      );

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'description': description,
        'image_url': imageUrl,
      };
}

class Product {
  final String id;
  final String categoryId;
  final Category? category;
  final String name;
  final String slug;
  final String description;
  final int price;
  final int costPrice; // harga modal (cost_price) — dipakai analitik profit
  final int stock;
  final String sku;
  final String imageUrl;
  final int weightGram;
  final bool isActive;
  final bool isAvailable; // toggle 1-klik Sold Out (tanpa ubah stok)
  final List<ModifierGroup> modifiers; // dari modifiers_json backend

  const Product({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    this.costPrice = 0,
    required this.stock,
    required this.sku,
    required this.imageUrl,
    required this.weightGram,
    required this.isActive,
    this.isAvailable = true,
    this.modifiers = const [],
  });

  String get categoryName => category?.name ?? '';

  /// Parse modifiers_json backend: bisa berupa string JSON, Map
  /// {groups:[...]}, atau List grup langsung. Gagal parse -> kosong.
  static List<ModifierGroup> parseModifiers(dynamic raw) {
    if (raw == null) return const [];
    try {
      dynamic decoded = raw;
      if (raw is String) {
        if (raw.trim().isEmpty) return const [];
        decoded = jsonDecode(raw);
      }
      if (decoded is Map<String, dynamic>) {
        final g = decoded['groups'];
        if (g is List) {
          return g
              .whereType<Map<String, dynamic>>()
              .map(ModifierGroup.fromJson)
              .toList();
        }
        return const [];
      }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(ModifierGroup.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: parseString(json['id']),
        categoryId: parseString(json['category_id']),
        category: json['category'] is Map<String, dynamic>
            ? Category.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        name: parseString(json['name']),
        slug: parseString(json['slug']),
        description: parseString(json['description']),
        price: parseInt(json['price']),
        costPrice: parseInt(json['cost_price']),
        stock: parseInt(json['stock']),
        sku: parseString(json['sku']),
        imageUrl: parseString(json['image_url']),
        weightGram: parseInt(json['weight_gram']),
        isActive: parseBool(json['is_active'], true),
        isAvailable: parseBool(json['is_available'], true),
        modifiers: parseModifiers(json['modifiers_json']),
      );

  Map<String, dynamic> toRequestJson() {
    final m = {
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'sku': sku,
      'image_url': imageUrl,
      'weight_gram': weightGram,
      'is_active': isActive,
      'is_available': isAvailable,
    };
    if (modifiers.isNotEmpty) {
      m['modifiers_json'] = jsonEncode({
        'groups': modifiers.map((g) => g.toJson()).toList(),
      });
    }
    return m;
  }

  Product copyWith({
    int? stock,
    bool? isAvailable,
    List<ModifierGroup>? modifiers,
    int? costPrice,
    bool? isActive,
  }) =>
      Product(
        id: id,
        categoryId: categoryId,
        category: category,
        name: name,
        slug: slug,
        description: description,
        price: price,
        costPrice: costPrice ?? this.costPrice,
        stock: stock ?? this.stock,
        sku: sku,
        imageUrl: imageUrl,
        weightGram: weightGram,
        isActive: isActive ?? this.isActive,
        isAvailable: isAvailable ?? this.isAvailable,
        modifiers: modifiers ?? this.modifiers,
      );
}

class Payment {
  final String id;
  final String transactionId;
  final String method;
  final int amount;
  final String status; // pending | settlement | expire | cancel | failed
  final String paymentUrl;
  final String qrString;
  final String? expiresAt;
  final String? paidAt;

  const Payment({
    required this.id,
    required this.transactionId,
    required this.method,
    required this.amount,
    required this.status,
    required this.paymentUrl,
    required this.qrString,
    required this.expiresAt,
    required this.paidAt,
  });

  bool get isPaid => status == 'settlement';

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: parseString(json['id']),
        transactionId: parseString(json['transaction_id']),
        method: parseString(json['method']),
        amount: parseInt(json['amount']),
        status: parseString(json['status'], 'pending'),
        paymentUrl: parseString(json['payment_url']),
        qrString: parseString(json['qr_string']),
        expiresAt: json['expires_at']?.toString(),
        paidAt: json['paid_at']?.toString(),
      );
}

class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final int price;
  final int quantity;
  final int subtotal;
  final String notes; // catatan dapur per item (guest checkout)
  final List<ModifierOption> selectedModifiers; // varian/add-on dipilih
  final int unitPrice; // harga dasar + harga add-on
  final int unitCost; // HPP dasar + HPP add-on

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.notes = '',
    this.selectedModifiers = const [],
    this.unitPrice = 0,
    this.unitCost = 0,
  });

  /// "Less Sugar, Extra Espresso Shot" — kosong bila tanpa varian.
  String get modifiersLabel =>
      selectedModifiers.map((m) => m.name).join(', ');

  /// Parse selected_modifiers: List map, string JSON, atau ringkasan teks.
  static List<ModifierOption> parseSelectedModifiers(dynamic raw) {
    if (raw == null) return const [];
    try {
      dynamic decoded = raw;
      if (raw is String) {
        if (raw.trim().isEmpty) return const [];
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          // Ringkasan teks polos, mis. "Less Sugar, Extra Shot".
          return raw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .map((s) => ModifierOption(name: s))
              .toList();
        }
      }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(ModifierOption.fromJson)
            .toList();
      }
      if (decoded is Map<String, dynamic>) {
        return [ModifierOption.fromJson(decoded)];
      }
    } catch (_) {}
    return const [];
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Nama produk bisa datang sebagai product_name (flat) atau
    // product.name (nested) — tergantung endpoint (member vs guest track).
    var name = parseString(json['product_name']);
    if (name.isEmpty && json['product'] is Map<String, dynamic>) {
      name = parseString(
        (json['product'] as Map<String, dynamic>)['name'],
      );
    }
    final price = parseInt(json['price']);
    return OrderItem(
      id: parseString(json['id']),
      productId: parseString(json['product_id']),
      productName: name,
      price: price,
      quantity: parseInt(json['quantity']),
      subtotal: parseInt(json['subtotal']),
      notes: parseString(json['notes']),
      selectedModifiers:
          parseSelectedModifiers(json['selected_modifiers']),
      unitPrice: parseInt(json['unit_price'], price),
      unitCost: parseInt(json['unit_cost']),
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String status; // pending|paid|processing|shipped|completed|cancelled
  final int subtotal;
  final int shippingCost;
  final int total;
  final String paymentMethod;
  final String notes;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddressText;
  final String orderType; // dine_in | takeaway | delivery
  final String tableNumber;
  final String processedByName; // nama staf yang memproses (audit trail)
  final int discountAmount; // potongan voucher (Rp)
  final String voucherCode; // kode voucher yang dipakai
  final List<OrderItem> items;
  final Payment? payment;
  final String createdAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.shippingCost,
    required this.total,
    required this.paymentMethod,
    required this.notes,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddressText,
    this.orderType = '',
    this.tableNumber = '',
    this.processedByName = '',
    this.discountAmount = 0,
    this.voucherCode = '',
    required this.items,
    required this.payment,
    required this.createdAt,
  });

  /// Label jenis pesanan untuk antrean dapur: "MEJA 05" / "TAKEAWAY" /
  /// "DELIVERY".
  String get orderTypeLabel {
    switch (orderType) {
      case 'dine_in':
        return tableNumber.isNotEmpty
            ? 'MEJA $tableNumber'
            : 'DINE-IN';
      case 'takeaway':
        return 'TAKEAWAY';
      case 'delivery':
        return 'DELIVERY';
      default:
        return orderType.isEmpty ? '-' : orderType.toUpperCase();
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList()
        : <OrderItem>[];
    return Order(
      id: parseString(json['id']),
      orderNumber: parseString(json['order_number']),
      status: parseString(json['status'], 'pending'),
      subtotal: parseInt(json['subtotal']),
      shippingCost: parseInt(json['shipping_cost']),
      total: parseInt(json['total']),
      paymentMethod: parseString(json['payment_method']),
      notes: parseString(json['notes']),
      shippingName: parseString(json['shipping_name']),
      shippingPhone: parseString(json['shipping_phone']),
      shippingAddressText: parseString(json['shipping_address_text']),
      orderType: parseString(json['order_type']),
      tableNumber: parseString(json['table_number']),
      processedByName: parseString(json['processed_by_name']),
      discountAmount: parseInt(json['discount_amount']),
      voucherCode: parseString(json['voucher_code']),
      items: items,
      payment: json['payment'] is Map<String, dynamic>
          ? Payment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      createdAt: parseString(json['created_at']),
    );
  }
}

/// Daftar ber-paginasi dari endpoint list backend.
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int totalPages;
  final int total;

  const PagedResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

// ---------------- Analitik profit admin ----------------
// GET /admin/analytics/profit?period=today|7d|30d|all
// (atau start_date & end_date YYYY-MM-DD). Respons data sesuai kontrak.

class ProfitSummary {
  final int grossRevenue;
  final int totalCogs;
  final int netProfit;
  final double profitMarginPercent;
  final int totalPaidOrders;
  final int averageOrderValue;
  final int pendingOrCancelledCount;

  const ProfitSummary({
    required this.grossRevenue,
    required this.totalCogs,
    required this.netProfit,
    required this.profitMarginPercent,
    required this.totalPaidOrders,
    required this.averageOrderValue,
    required this.pendingOrCancelledCount,
  });

  factory ProfitSummary.fromJson(Map<String, dynamic> json) => ProfitSummary(
        grossRevenue: parseInt(json['gross_revenue']),
        totalCogs: parseInt(json['total_cogs']),
        netProfit: parseInt(json['net_profit']),
        profitMarginPercent: parseDouble(json['profit_margin_percent']),
        totalPaidOrders: parseInt(json['total_paid_orders']),
        averageOrderValue: parseInt(json['average_order_value']),
        pendingOrCancelledCount:
            parseInt(json['pending_or_cancelled_count']),
      );

  static const empty = ProfitSummary(
    grossRevenue: 0,
    totalCogs: 0,
    netProfit: 0,
    profitMarginPercent: 0,
    totalPaidOrders: 0,
    averageOrderValue: 0,
    pendingOrCancelledCount: 0,
  );
}

class DailyProfitPoint {
  final String date;
  final int revenue;
  final int profit;
  final int ordersCount;

  const DailyProfitPoint({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.ordersCount,
  });

  factory DailyProfitPoint.fromJson(Map<String, dynamic> json) =>
      DailyProfitPoint(
        date: parseString(json['date']),
        revenue: parseInt(json['revenue']),
        profit: parseInt(json['profit']),
        ordersCount: parseInt(json['orders_count']),
      );
}

class OrderTypeProfit {
  final String orderType;
  final int revenue;
  final int ordersCount;

  const OrderTypeProfit({
    required this.orderType,
    required this.revenue,
    required this.ordersCount,
  });

  factory OrderTypeProfit.fromJson(Map<String, dynamic> json) =>
      OrderTypeProfit(
        orderType: parseString(json['order_type']),
        revenue: parseInt(json['revenue']),
        ordersCount: parseInt(json['orders_count']),
      );
}

class PaymentMethodProfit {
  final String paymentMethod;
  final int revenue;
  final int ordersCount;

  const PaymentMethodProfit({
    required this.paymentMethod,
    required this.revenue,
    required this.ordersCount,
  });

  factory PaymentMethodProfit.fromJson(Map<String, dynamic> json) =>
      PaymentMethodProfit(
        paymentMethod: parseString(json['payment_method']),
        revenue: parseInt(json['revenue']),
        ordersCount: parseInt(json['orders_count']),
      );
}

class TopProduct {
  final String productId;
  final String productName;
  final int quantitySold;
  final int revenue;
  final int profit;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.profit,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productId: parseString(json['product_id']),
        productName: parseString(json['product_name']),
        quantitySold: parseInt(json['quantity_sold']),
        revenue: parseInt(json['revenue']),
        profit: parseInt(json['profit']),
      );
}

class RecentTransaction {
  final String orderNumber;
  final String customerName;
  final String orderType;
  final String tableNumber;
  final String status;
  final int total;
  final String processedByName; // nama staf yang memproses (audit trail)
  final String createdAt;

  const RecentTransaction({
    required this.orderNumber,
    required this.customerName,
    required this.orderType,
    required this.tableNumber,
    required this.status,
    required this.total,
    this.processedByName = '',
    required this.createdAt,
  });

  factory RecentTransaction.fromJson(Map<String, dynamic> json) =>
      RecentTransaction(
        orderNumber: parseString(json['order_number']),
        customerName: parseString(json['customer_name']),
        orderType: parseString(json['order_type']),
        tableNumber: parseString(json['table_number']),
        status: parseString(json['status']),
        total: parseInt(json['total']),
        processedByName: parseString(json['processed_by_name']),
        createdAt: parseString(json['created_at']),
      );
}

class ProfitAnalytics {
  final String period;
  final String startDate;
  final String endDate;
  final ProfitSummary summary;
  final List<DailyProfitPoint> dailySeries;
  final List<OrderTypeProfit> byOrderType;
  final List<PaymentMethodProfit> byPaymentMethod;
  final List<TopProduct> topProducts;
  final List<RecentTransaction> recentTransactions;

  const ProfitAnalytics({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.dailySeries,
    required this.byOrderType,
    required this.byPaymentMethod,
    required this.topProducts,
    required this.recentTransactions,
  });

  factory ProfitAnalytics.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) parse,
    ) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList();
    }

    final summaryJson = json['summary'];
    return ProfitAnalytics(
      period: parseString(json['period']),
      startDate: parseString(json['start_date']),
      endDate: parseString(json['end_date']),
      summary: summaryJson is Map<String, dynamic>
          ? ProfitSummary.fromJson(summaryJson)
          : ProfitSummary.empty,
      dailySeries: listOf(json['daily_series'], DailyProfitPoint.fromJson),
      byOrderType: listOf(json['by_order_type'], OrderTypeProfit.fromJson),
      byPaymentMethod:
          listOf(json['by_payment_method'], PaymentMethodProfit.fromJson),
      topProducts: listOf(json['top_products'], TopProduct.fromJson),
      recentTransactions:
          listOf(json['recent_transactions'], RecentTransaction.fromJson),
    );
  }
}

// ---------------- Voucher promo ----------------
// GET/POST/PUT/DELETE /admin/vouchers (admin/superadmin).

class Voucher {
  final String id;
  final String code; // unik, uppercase
  final String discountType; // "percentage" | "fixed"
  final int discountValue; // % atau Rp
  final int minOrderAmount;
  final int maxDiscount; // 0 = tanpa batas
  final int quota; // 0 = tanpa batas
  final int usedCount;
  final bool isActive;
  final String? expiresAt; // ISO / YYYY-MM-DD

  const Voucher({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount = 0,
    this.maxDiscount = 0,
    this.quota = 0,
    this.usedCount = 0,
    this.isActive = true,
    this.expiresAt,
  });

  String get discountLabel => discountType == 'percentage'
      ? 'DISKON $discountValue%'
      : 'POTONGAN ${formatRupiah(discountValue)}';

  String get quotaLabel =>
      quota > 0 ? '$usedCount/$quota dipakai' : '$usedCount dipakai';

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: parseString(json['id']),
        code: parseString(json['code']).toUpperCase(),
        discountType: parseString(json['discount_type'], 'fixed'),
        discountValue: parseInt(json['discount_value']),
        minOrderAmount: parseInt(json['min_order_amount']),
        maxDiscount: parseInt(json['max_discount']),
        quota: parseInt(json['quota']),
        usedCount: parseInt(json['used_count']),
        isActive: parseBool(json['is_active'], true),
        expiresAt: json['expires_at']?.toString(),
      );

  Map<String, dynamic> toRequestJson() => {
        'code': code.toUpperCase(),
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_order_amount': minOrderAmount,
        'max_discount': maxDiscount,
        'quota': quota,
        'is_active': isActive,
        if (expiresAt != null && expiresAt!.isNotEmpty)
          'expires_at': expiresAt,
      };
}

// ---------------- Loyalitas pelanggan (via nomor HP) ----------------
// GET /loyalty/:phone -> {phone, points, reward_eligible}.

class LoyaltyInfo {
  final String phone;
  final int points; // stamp terkumpul (1 per pesanan lunas / per Rp20rb)
  final bool rewardEligible; // true bila sudah 10 poin

  const LoyaltyInfo({
    required this.phone,
    this.points = 0,
    this.rewardEligible = false,
  });

  factory LoyaltyInfo.fromJson(Map<String, dynamic> json) => LoyaltyInfo(
        phone: parseString(json['phone']),
        points: parseInt(json['points']),
        rewardEligible: parseBool(json['reward_eligible'], false),
      );
}
