
class InvoiceItem {
  final int id;
  final int product;
  final String productName;
  final String productCategory;
  final String sellingType;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  InvoiceItem({
    required this.id,
    required this.product,
    required this.productName,
    required this.productCategory,
    required this.sellingType,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  bool get isLoose => sellingType.toUpperCase() == 'KG';

  String get formattedQuantity {
    if (isLoose) {
      if (quantity < 1.0) {
        return '${(quantity * 1000).toInt()} g';
      }
      return '${quantity.toStringAsFixed(3)} kg';
    }

    return '${quantity.toInt()} units';
  }

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: _toInt(json['id']) ?? 0,
      product: _toInt(json['product']) ?? 0,
      productName: json['product_name']?.toString() ?? 'Item',
      productCategory: json['product_category']?.toString() ?? '',
      sellingType: json['unit']?.toString() ??
          json['selling_type']?.toString() ??
          'UNIT',
      quantity: _toDouble(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
      totalPrice: _toDouble(json['line_total'] ?? json['total_price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product,
      'product_name': productName,
      'unit': sellingType,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': totalPrice,
    };
  }
}