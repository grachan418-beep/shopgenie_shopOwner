
class Product {
  final int id;
  final int? user;
  final String name;
  final String category;
  final String sellingType;
  final double costPrice;
  final double pricePerUnit;
  final double quantity;
  final String formattedQuantity;
  final List<double>? featureVector;
  final bool isLoose;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    this.user,
    required this.name,
    required this.category,
    required this.sellingType,
    required this.costPrice,
    required this.pricePerUnit,
    required this.quantity,
    String? formattedQuantity,
    this.featureVector,
    required this.isLoose,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  }) : formattedQuantity =
      formattedQuantity ?? _formatQuantity(quantity, sellingType);

  bool get isUnit => sellingType.toUpperCase() == 'UNIT';

  bool get isKg => sellingType.toUpperCase() == 'KG';

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

  static String _formatQuantity(double quantity, String sellingType) {
    if (sellingType.toUpperCase() == 'KG') {
      return '${quantity.toStringAsFixed(3)} kg';
    }

    final units = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();

    return '$units units';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final unit = json['unit']?.toString() ?? 'PIECE';
    final sellingType = unit == 'KG' ? 'KG' : 'UNIT';
    final quantity = _toDouble(json['stock_quantity'] ?? json['quantity']);
    final rawFormattedQuantity = json['formatted_quantity']?.toString();
    final rawCreatedAt = json['created_at'];
    final rawUpdatedAt = json['updated_at'];

    return Product(
      id: _toInt(json['id']) ?? 0,
      user: _toInt(json['shop'] ?? json['user']),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      sellingType: sellingType,
      costPrice: _toDouble(json['cost_price']),
      pricePerUnit: _toDouble(json['selling_price'] ?? json['price_per_unit']),
      quantity: quantity,
      formattedQuantity:
      rawFormattedQuantity == null || rawFormattedQuantity.isEmpty
          ? _formatQuantity(quantity, sellingType)
          : rawFormattedQuantity,
      isLoose: unit == 'KG',
      imageUrl: json['image_url']?.toString(),
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : null,
      updatedAt: rawUpdatedAt is String
          ? DateTime.tryParse(rawUpdatedAt)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (user != null) 'user': user,
      'name': name,
      'category': category,
      'unit': sellingType == 'KG' ? 'KG' : 'PIECE',
      'cost_price': costPrice,
      'mrp': pricePerUnit,
      'selling_price': pricePerUnit,
      'stock_quantity': quantity,
      'formatted_quantity': formattedQuantity,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  Product copyWith({
    int? id,
    int? user,
    String? name,
    String? category,
    String? sellingType,
    double? costPrice,
    double? pricePerUnit,
    double? quantity,
    String? formattedQuantity,
    List<double>? featureVector,
    bool? isLoose,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      user: user ?? this.user,
      name: name ?? this.name,
      category: category ?? this.category,
      sellingType: sellingType ?? this.sellingType,
      costPrice: costPrice ?? this.costPrice,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      quantity: quantity ?? this.quantity,
      formattedQuantity: formattedQuantity,
      featureVector: featureVector ?? this.featureVector,
      isLoose: isLoose ?? this.isLoose,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}