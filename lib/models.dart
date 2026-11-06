import 'utils.dart';

/// Model-model domain, dipetakan 1:1 dari JSON backend Go
/// (lihat ecommerce-api/internal/domain/*.go).

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
  });

  String get categoryName => category?.name ?? '';

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
      );

  Map<String, dynamic> toRequestJson() => {
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
      };
}

class CartItem {
  final String id;
  final String productId;
  final Product? product;
  final int quantity;
  final int price;

  const CartItem({
    required this.id,
    required this.productId,
    required this.product,
    required this.quantity,
    required this.price,
  });

  int get subtotal => price * quantity;
  String get productName => product?.name ?? 'Produk';

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: parseString(json['id']),
        productId: parseString(json['product_id']),
        product: json['product'] is Map<String, dynamic>
            ? Product.fromJson(json['product'] as Map<String, dynamic>)
            : null,
        quantity: parseInt(json['quantity']),
        price: parseInt(json['price']),
      );
}

class Cart {
  final String id;
  final List<CartItem> items;
  final int subtotal;
  final int totalItems;

  const Cart({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.totalItems,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    // GET /cart mengembalikan data: {cart: {...}, subtotal, total_items}
    final cartJson = json['cart'];
    if (cartJson is Map<String, dynamic>) {
      final rawItems = cartJson['items'];
      final items = rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(CartItem.fromJson)
              .toList()
          : <CartItem>[];
      return Cart(
        id: parseString(cartJson['id']),
        items: items,
        subtotal: parseInt(json['subtotal']),
        totalItems: parseInt(json['total_items']),
      );
    }
    return const Cart(id: '', items: [], subtotal: 0, totalItems: 0);
  }

  static const empty = Cart(id: '', items: [], subtotal: 0, totalItems: 0);
}

class Address {
  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String street;
  final String city;
  final String province;
  final String postalCode;
  final bool isDefault;

  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.isDefault,
  });

  String get fullAddress =>
      '$street, $city, $province $postalCode';

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: parseString(json['id']),
        label: parseString(json['label']),
        recipientName: parseString(json['recipient_name']),
        phone: parseString(json['phone']),
        street: parseString(json['street']),
        city: parseString(json['city']),
        province: parseString(json['province']),
        postalCode: parseString(json['postal_code']),
        isDefault: parseBool(json['is_default']),
      );

  Map<String, dynamic> toRequestJson() => {
        'label': label,
        'recipient_name': recipientName,
        'phone': phone,
        'street': street,
        'city': city,
        'province': province,
        'postal_code': postalCode,
        'is_default': isDefault,
      };
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

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.notes = '',
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Nama produk bisa datang sebagai product_name (flat) atau
    // product.name (nested) — tergantung endpoint (member vs guest track).
    var name = parseString(json['product_name']);
    if (name.isEmpty && json['product'] is Map<String, dynamic>) {
      name = parseString(
        (json['product'] as Map<String, dynamic>)['name'],
      );
    }
    return OrderItem(
      id: parseString(json['id']),
      productId: parseString(json['product_id']),
      productName: name,
      price: parseInt(json['price']),
      quantity: parseInt(json['quantity']),
      subtotal: parseInt(json['subtotal']),
      notes: parseString(json['notes']),
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
  final String processedByName; // nama staf yang memproses (audit trail)
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
    this.processedByName = '',
    required this.items,
    required this.payment,
    required this.createdAt,
  });

  bool get canCancel => status == 'pending' || status == 'paid';

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
      processedByName: parseString(json['processed_by_name']),
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

/// Satu item untuk request guest checkout:
/// POST /orders/guest-checkout {items: [{product_id, quantity, notes}]}.
class GuestCheckoutItem {
  final String productId;
  final int quantity;
  final String notes;

  const GuestCheckoutItem({
    required this.productId,
    required this.quantity,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'notes': notes,
      };
}

/// Item keranjang lokal tamu — disimpan di perangkat (SharedPreferences),
/// tanpa login. Harga disalin saat ditambah (snapshot) agar subtotal
/// tetap benar walau harga di server berubah.
class LocalCartItem {
  final String productId;
  final String name;
  final int price;
  final String imageUrl;
  final int quantity;
  final String notes;

  const LocalCartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    this.notes = '',
  });

  int get subtotal => price * quantity;

  factory LocalCartItem.fromProduct(Product p, int quantity) => LocalCartItem(
        productId: p.id,
        name: p.name,
        price: p.price,
        imageUrl: p.imageUrl,
        quantity: quantity,
      );

  factory LocalCartItem.fromJson(Map<String, dynamic> json) => LocalCartItem(
        productId: parseString(json['product_id']),
        name: parseString(json['name']),
        price: parseInt(json['price']),
        imageUrl: parseString(json['image_url']),
        quantity: parseInt(json['quantity'], 1),
        notes: parseString(json['notes']),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'price': price,
        'image_url': imageUrl,
        'quantity': quantity,
        'notes': notes,
      };

  LocalCartItem copyWith({int? quantity, String? notes}) => LocalCartItem(
        productId: productId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
      );
}

/// Nomor order tamu yang disimpan di perangkat, untuk menu
/// "Pesanan Saya" tanpa login (dilacak via /orders/track/:order_number).
class GuestOrderEntry {
  final String orderNumber;
  final String savedAt; // ISO-8601

  const GuestOrderEntry({required this.orderNumber, required this.savedAt});

  factory GuestOrderEntry.fromJson(Map<String, dynamic> json) =>
      GuestOrderEntry(
        orderNumber: parseString(json['order_number']),
        savedAt: parseString(json['saved_at']),
      );

  Map<String, dynamic> toJson() => {
        'order_number': orderNumber,
        'saved_at': savedAt,
      };
}

/// Satu baris keranjang yang seragam untuk tamu & member — dipakai
/// Floating Cart Bar + sheet edit keranjang. `key` = id yang dipakai
/// setQty/remove (productId untuk tamu, cart item id untuk member).
class CartLine {
  final String key;
  final String productId;
  final String name;
  final int price;
  final int quantity;
  final String imageUrl;

  const CartLine({
    required this.key,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl = '',
  });

  int get subtotal => price * quantity;
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
