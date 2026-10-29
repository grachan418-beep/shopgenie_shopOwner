
import 'package:flutter_test/flutter_test.dart';
import 'package:shopgenie_flutter/models/product.dart';
import 'package:shopgenie_flutter/services/cart_service.dart';

void main() {
  group('CartService Tests', () {
    late CartService cartService;
    late Product unitProduct;
    late Product kgProduct;

    setUp(() {
      cartService = CartService();
      cartService.clear();

      unitProduct = Product(
        id: 1,
        name: 'Parle-G 100g',
        category: 'Snacks',
        sellingType: 'UNIT',
        costPrice: 8.0,
        pricePerUnit: 10.0,
        quantity: 50.0,
        isLoose: false,
        formattedQuantity: '50 units',
      );

      kgProduct = Product(
        id: 2,
        name: 'Basmati Rice',
        category: 'Grains',
        sellingType: 'KG',
        costPrice: 80.0,
        pricePerUnit: 120.0,
        quantity: 25.0,
        isLoose: true,
        formattedQuantity: '25.000 kg',
      );
    });

    test('Initial cart is empty', () {
      expect(cartService.items, isEmpty);
      expect(cartService.totalAmount, 0.0);
      expect(cartService.itemCount, 0);
    });

    test('Add unit product increases quantity and total correctly', () {
      cartService.addProduct(unitProduct, quantity: 2.0);

      expect(cartService.items.length, 1);
      expect(cartService.items.first.quantity, 2.0);
      expect(cartService.totalAmount, 20.0);
      expect(cartService.itemCount, 2);
    });

    test('Add kg product calculates decimal subtotal correctly', () {
      cartService.addProduct(kgProduct, quantity: 1.5);

      expect(cartService.items.length, 1);
      expect(cartService.items.first.quantity, 1.5);
      expect(cartService.totalAmount, 180.0);
    });

    test('Increment and decrement unit quantity', () {
      cartService.addProduct(unitProduct, quantity: 1.0);

      expect(cartService.items.first.quantity, 1.0);

      cartService.incrementQuantity(unitProduct.id);
      expect(cartService.items.first.quantity, 2.0);

      cartService.decrementQuantity(unitProduct.id);
      expect(cartService.items.first.quantity, 1.0);

      cartService.decrementQuantity(unitProduct.id);
      expect(cartService.items, isEmpty);
    });

    test('Remove item removes product from cart', () {
      cartService.addProduct(unitProduct, quantity: 2.0);
      cartService.addProduct(kgProduct, quantity: 1.0);

      expect(cartService.items.length, 2);

      cartService.removeItem(unitProduct.id);

      expect(cartService.items.length, 1);
      expect(cartService.items.first.product.id, kgProduct.id);
    });

    test('Clear empties all cart items', () {
      cartService.addProduct(unitProduct, quantity: 2.0);
      cartService.addProduct(kgProduct, quantity: 1.0);

      cartService.clear();

      expect(cartService.items, isEmpty);
      expect(cartService.totalAmount, 0.0);
    });
  });
}
