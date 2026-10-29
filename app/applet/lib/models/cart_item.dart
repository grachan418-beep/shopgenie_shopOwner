import 'product.dart';

class CartItem {
  final Product product;
  double quantity; // Decimal representation (e.g. 1.0, 2.0 for UNIT, or 0.750, 1.250 for KG)

  CartItem({
    required this.product,
    required this.quantity,
  });

  bool get isLoose => product.sellingType.toUpperCase() == 'KG';

  double get unitPrice => product.pricePerUnit;

  double get subtotal => double.parse((quantity * unitPrice).toStringAsFixed(2));

  String get formattedQuantity {
    if (isLoose) {
      if (quantity < 1.0) {
        return '${(quantity * 1000).toInt()} g';
      }
      return '${quantity.toStringAsFixed(3)} kg';
    } else {
      return '${quantity.toInt()} units';
    }
  }

  Map<String, dynamic> toCheckoutPayload([int? invoiceId]) {
    return {
      'product_id': product.id,
      'quantity': isLoose ? double.parse(quantity.toStringAsFixed(3)) : quantity.toInt(),
      if (invoiceId != null) 'invoice_id': invoiceId,
    };
  }
}
