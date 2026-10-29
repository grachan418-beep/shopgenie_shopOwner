import 'dart:math';

import '../models/cart_item.dart';
import '../models/invoice.dart';
import 'api_service.dart';

class CheckoutResult {
  final bool success;
  final Invoice? invoice;
  final String? errorMessage;
  final int billedItemsCount;

  CheckoutResult({
    required this.success,
    this.invoice,
    this.errorMessage,
    this.billedItemsCount = 0,
  });
}

class CheckoutService {
  static final CheckoutService _instance = CheckoutService._internal();
  factory CheckoutService() => _instance;
  CheckoutService._internal();

  final ApiService _api = ApiService();

  Future<CheckoutResult> checkoutCart(List<CartItem> items, {void Function(int current, int total)? onProgress}) async {
    if (items.isEmpty) {
      return CheckoutResult(success: false, errorMessage: 'Cart is empty.');
    }

    onProgress?.call(1, 1);
    try {
      final random = Random.secure();
      final idempotencyKey =
          'checkout-${DateTime.now().toUtc().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
      final response = await _api.post(
        '/api/billing/invoices/',
        body: {
          'idempotency_key': idempotencyKey,
          'items': items
              .map((item) => {
                    'product_id': item.product.id,
                    'quantity': item.isLoose
                        ? double.parse(item.quantity.toStringAsFixed(3))
                        : item.quantity.toInt(),
                  })
              .toList(),
        },
      );
      if (response is! Map<String, dynamic>) {
        throw ApiException('The server returned an invalid invoice response.');
      }
      return CheckoutResult(
        success: true,
        invoice: Invoice.fromJson(response),
        billedItemsCount: items.length,
      );
    } on ApiException catch (error) {
      return CheckoutResult(
        success: false,
        errorMessage: error.message,
      );
    }
  }

  Future<Invoice> acceptSingleItem({
    required int productId,
    required double quantity,
    int? invoiceId,
  }) async {
    final random = Random.secure();
    final response = await _api.post(
      '/api/billing/invoices/',
      body: {
        'idempotency_key':
            'checkout-${DateTime.now().toUtc().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}',
        'items': [
          {'product_id': productId, 'quantity': quantity},
        ],
      },
    );
    if (response is! Map<String, dynamic>) {
      throw ApiException('The server returned an invalid invoice response.');
    }
    return Invoice.fromJson(response);
  }
}
