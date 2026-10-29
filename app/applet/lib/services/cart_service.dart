
import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();

  factory CartService() => _instance;

  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  /// Total count of individual UNIT products in the cart.
  /// KG products count as one cart line, not kilograms.
  int get itemCount {
    int count = 0;

    for (final item in _items) {
      if (item.isLoose) {
        count += 1;
      } else {
        count += item.quantity.toInt();
      }
    }

    return count;
  }

  bool get isEmpty => _items.isEmpty;

  double get totalAmount {
    double total = 0.0;

    for (final item in _items) {
      total += item.subtotal;
    }

    return double.parse(total.toStringAsFixed(2));
  }

  int get totalUnitQuantity {
    int units = 0;

    for (final item in _items) {
      if (!item.isLoose) {
        units += item.quantity.toInt();
      } else {
        units += 1;
      }
    }

    return units;
  }

  CartItem? findByProductId(int productId) {
    try {
      return _items.firstWhere((item) => item.product.id == productId);
    } catch (_) {
      return null;
    }
  }

  void addProduct(Product product, {double quantity = 1.0}) {
    if (quantity <= 0) return;

    final existing = findByProductId(product.id);

    if (existing != null) {
      existing.quantity += quantity;

      if (existing.isLoose) {
        existing.quantity =
            double.parse(existing.quantity.toStringAsFixed(3));
      } else {
        existing.quantity = existing.quantity.roundToDouble();
      }
    } else {
      _items.add(
        CartItem(
          product: product,
          quantity: product.isKg
              ? double.parse(quantity.toStringAsFixed(3))
              : quantity.roundToDouble(),
        ),
      );
    }

    notifyListeners();
  }

  void updateQuantity(int productId, double newQuantity) {
    if (newQuantity <= 0) {
      removeItem(productId);
      return;
    }

    final item = findByProductId(productId);

    if (item != null) {
      if (item.isLoose) {
        item.quantity = double.parse(newQuantity.toStringAsFixed(3));
      } else {
        item.quantity = newQuantity.roundToDouble();
      }

      notifyListeners();
    }
  }

  void incrementQuantity(int productId) {
    final item = findByProductId(productId);

    if (item != null) {
      if (item.isLoose) {
        updateQuantity(productId, item.quantity + 0.100);
      } else {
        updateQuantity(productId, item.quantity + 1.0);
      }
    }
  }

  void decrementQuantity(int productId) {
    final item = findByProductId(productId);

    if (item != null) {
      if (item.isLoose) {
        updateQuantity(productId, item.quantity - 0.100);
      } else {
        updateQuantity(productId, item.quantity - 1.0);
      }
    }
  }

  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}