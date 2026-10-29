
import 'package:flutter_test/flutter_test.dart';
import 'package:shopgenie_flutter/models/product.dart';
import 'package:shopgenie_flutter/models/scan_result.dart';
import 'package:shopgenie_flutter/models/invoice.dart';

void main() {
  group('Model Serialization & Logic Tests', () {
    test('Product JSON serialization and getters', () {
      final json = {
        'id': 10,
        'name': 'Tata Salt 1kg',
        'category': 'Spices & Essentials',
        'selling_type': 'UNIT',
        'cost_price': '20.00',
        'price_per_unit': '25.00',
        'quantity': '100.000',
        'is_loose': false,
        'feature_vector': [0.12, 0.34, 0.56],
      };

      final product = Product.fromJson(json);

      expect(product.id, 10);
      expect(product.name, 'Tata Salt 1kg');
      expect(product.isUnit, isTrue);
      expect(product.isKg, isFalse);
      expect(product.costPrice, 20.0);
      expect(product.pricePerUnit, 25.0);
      expect(product.quantity, 100.0);
      expect(product.formattedQuantity, '100 units');
      expect(product.featureVector, isNotNull);
      expect(product.featureVector!.length, 3);

      final outJson = product.toJson();

      expect(outJson['name'], 'Tata Salt 1kg');
      expect(outJson['selling_type'], 'UNIT');
    });

    test('Loose Product formatted quantity', () {
      final product = Product(
        id: 11,
        name: 'Sugar M30',
        category: 'Essentials',
        sellingType: 'KG',
        costPrice: 38.0,
        pricePerUnit: 44.0,
        quantity: 12.500,
        isLoose: true,
        formattedQuantity: '12.500 kg',
      );

      expect(product.isKg, isTrue);
      expect(product.isUnit, isFalse);
      expect(product.formattedQuantity, '12.500 kg');
    });

    test('ScanResult branded vs loose candidate handling', () {
      final matchJson = {
        'status': 'MATCHED',
        'matched_product': {
          'id': 5,
          'name': 'Maggi Noodles 70g',
          'category': 'Snacks',
          'selling_type': 'UNIT',
          'price_per_unit': 14.0,
          'cost_price': 11.5,
          'quantity': 45.0,
          'is_loose': false,
        },
        'confidence': 0.92,
        'message': 'Product identified with high confidence',
      };

      final matchResult = ScanResult.fromJson(matchJson);

      expect(matchResult.isProductMatch, isTrue);
      expect(matchResult.isLooseCandidates, isFalse);
      expect(matchResult.confidencePercentage, 92);
      expect(matchResult.toProduct()?.name, 'Maggi Noodles 70g');

      final looseJson = {
        'status': 'LOOSE_CANDIDATES',
        'message': 'Plain bag detected. Choose matching commodity.',
        'candidates': [
          {
            'id': 1,
            'name': 'Toor Dal',
            'category': 'Pulses',
            'selling_type': 'KG',
            'price_per_unit': 160.0,
            'cost_price': 130.0,
            'quantity': 20.0,
            'is_loose': true,
          }
        ],
      };

      final looseResult = ScanResult.fromJson(looseJson);

      expect(looseResult.isProductMatch, isFalse);
      expect(looseResult.isLooseCandidates, isTrue);
      expect(looseResult.candidates.length, 1);
      expect(looseResult.candidates.first.name, 'Toor Dal');
    });

    test('Invoice and InvoiceItem parsing', () {
      final invoiceJson = {
        'id': 101,
        'created_at': '2026-09-07T10:30:00Z',
        'total_amount': '250.00',
        'status': 'PAID',
        'items': [
          {
            'id': 1,
            'product': 10,
            'product_name': 'Tata Salt 1kg',
            'selling_type': 'UNIT',
            'quantity': '2.000',
            'unit_price': '25.00',
            'total_price': '50.00',
          },
          {
            'id': 2,
            'product': 11,
            'product_name': 'Sugar M30',
            'selling_type': 'KG',
            'quantity': '4.545',
            'unit_price': '44.00',
            'total_price': '200.00',
          }
        ],
      };

      final invoice = Invoice.fromJson(invoiceJson);

      expect(invoice.id, 101);
      expect(invoice.totalAmount, 250.0);
      expect(invoice.items.length, 2);
      expect(invoice.itemCount, 2);
      expect(invoice.items[0].formattedQuantity, '2 units');
      expect(invoice.items[1].formattedQuantity, '4.545 kg');
    });
  });
}