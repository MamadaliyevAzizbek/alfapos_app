import '../providers/clients_provider.dart';
import 'cart_item.dart';

/// Desktop POS: bir sotuv oynasining to‘liq holati (savatcha, mijoz, foiz).
class SalesWindowSnapshot {
  final List<CartItem> cartItems;
  final Client? client;
  final int discountPercent;
  final bool isReturnMode;
  final int? holdOrderId;
  final String? holdInvoiceId;

  const SalesWindowSnapshot({
    this.cartItems = const [],
    this.client,
    this.discountPercent = 0,
    this.isReturnMode = false,
    this.holdOrderId,
    this.holdInvoiceId,
  });

  factory SalesWindowSnapshot.empty() => const SalesWindowSnapshot();

  SalesWindowSnapshot copyWith({
    List<CartItem>? cartItems,
    Client? client,
    bool clearClient = false,
    int? discountPercent,
    bool? isReturnMode,
    int? holdOrderId,
    String? holdInvoiceId,
    bool clearHold = false,
  }) {
    return SalesWindowSnapshot(
      cartItems: cartItems ?? this.cartItems,
      client: clearClient ? null : (client ?? this.client),
      discountPercent: discountPercent ?? this.discountPercent,
      isReturnMode: isReturnMode ?? this.isReturnMode,
      holdOrderId: clearHold ? null : (holdOrderId ?? this.holdOrderId),
      holdInvoiceId: clearHold ? null : (holdInvoiceId ?? this.holdInvoiceId),
    );
  }
}
