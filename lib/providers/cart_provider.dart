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

  static bool _sameSaleOverride(double? a, double? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a - b).abs() < 0.01;
  }

  void add(CartItem item) {
    final i = _items.indexWhere((e) =>
        e.product.id == item.product.id &&
        e.sellByPack == item.sellByPack &&
        _sameSaleOverride(e.salePriceOverride, item.salePriceOverride));
    if (i >= 0) {
      _items[i].quantity = _items[i].quantity + item.quantity;
    } else {
      _items.add(item);
    }
    _controller.add(items);
  }

  void remove(CartItem item) {
    _items.remove(item);
    _controller.add(items);
  }

  void updateQuantity(CartItem item, num quantity) {
    if (quantity <= 0) {
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

  void clear() {
    _items.clear();
    _controller.add(items);
  }

  void dispose() {
    _controller.close();
  }
}
