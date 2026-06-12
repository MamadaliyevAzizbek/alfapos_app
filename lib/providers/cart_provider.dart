import 'dart:async';
import '../models/cart_item.dart';

class CartProvider {
  CartProvider._();
  static final CartProvider _instance = CartProvider._();
  static CartProvider get instance => _instance;

  final List<CartItem> _items = [];
  final _controller = StreamController<List<CartItem>>.broadcast();

  Stream<List<CartItem>> get stream => _controller.stream;
  List<CartItem> get items => List.unmodifiable(_items);
  num get count => _items.fold<num>(0, (sum, e) => sum + e.quantity);

  /// Bir xil mahsulot qatori: ID + variant + dona/pachka (chegirmali narx alohida emas).
  static bool isSameCartLine(CartItem a, CartItem b) {
    if (a.sellByPack != b.sellByPack) return false;
    if (a.product.id != b.product.id) return false;
    final va = a.product.variantId;
    final vb = b.product.variantId;
    if (va == null && vb == null) return true;
    if (va == null || vb == null) return va == vb;
    return va == vb;
  }

  /// Qo'shilgan yoki miqdori oshirilgan qatorni qaytaradi (har doim ro'yxat boshida).
  CartItem add(CartItem item) {
    final i = _items.indexWhere((e) => isSameCartLine(e, item));
    final CartItem line;
    if (i >= 0) {
      final existing = _items.removeAt(i);
      existing.quantity = existing.quantity + item.quantity;
      line = existing;
    } else {
      line = item;
    }
    _items.insert(0, line);
    _controller.add(items);
    return line;
  }

  void remove(CartItem item) {
    _items.remove(item);
    _controller.add(items);
  }

  void updateQuantity(CartItem item, num quantity) {
    if (quantity == 0) {
      _items.remove(item);
    } else {
      item.quantity = quantity;
    }
    _controller.add(items);
  }

  void updateSalePriceOverride(CartItem item, double? override) {
    if (!_items.contains(item)) return;
    item.salePriceOverride = override;
    _controller.add(items);
  }

  void updateSellByPack(CartItem item, bool sellByPack) {
    if (!_items.contains(item)) return;
    if (item.sellByPack == sellByPack) return;
    item.sellByPack = sellByPack;
    _controller.add(items);
  }

  void clear() {
    _items.clear();
    _controller.add(items);
  }

  void replaceAll(Iterable<CartItem> items) {
    _items
      ..clear()
      ..addAll(items);
    _controller.add(this.items);
  }

  void dispose() {
    _controller.close();
  }
}
