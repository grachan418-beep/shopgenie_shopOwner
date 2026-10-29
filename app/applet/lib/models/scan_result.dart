
import 'product.dart';

enum MatchType {
  product,
  looseCandidates,
  unknown,
}

class ScanResult {
  final MatchType matchType;
  final int? productId;
  final String? name;
  final String? category;
  final String? sellingType;
  final double? costPrice;
  final double? pricePerUnit;
  final double? quantity;
  final String? formattedQuantity;
  final double? similarity;
  final String? message;
  final List<Product> candidates;

  ScanResult({
    required this.matchType,
    this.productId,
    this.name,
    this.category,
    this.sellingType,
    this.costPrice,
    this.pricePerUnit,
    this.quantity,
    this.formattedQuantity,
    this.similarity,
    this.message,
    this.candidates = const [],
  });

  bool get isProductMatch => matchType == MatchType.product;

  bool get isLooseCandidates => matchType == MatchType.looseCandidates;

  int get confidencePercentage =>
      similarity == null ? 0 : (similarity! * 100).round().clamp(0, 100);

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    // Support both the API's match_type format and the test's status format.
    final rawType = (json['match_type'] ?? json['status'] ?? '')
        .toString()
        .toUpperCase();

    final matchedProduct = json['matched_product'] is Map
        ? Map<String, dynamic>.from(json['matched_product'] as Map)
        : <String, dynamic>{};

    final rawCandidates = json['candidates'];
    final candidateList = rawCandidates is List
        ? rawCandidates
        .whereType<Map>()
        .map((item) => Product.fromJson(
      Map<String, dynamic>.from(item),
    ))
        .toList()
        : <Product>[];

    final isLoose = rawType == 'LOOSE_CANDIDATES';
    final isMatched = rawType == 'PRODUCT' ||
        rawType == 'MATCHED' ||
        matchedProduct.isNotEmpty;

    final effectiveType = isLoose
        ? MatchType.looseCandidates
        : isMatched
        ? MatchType.product
        : MatchType.unknown;

    // Prefer nested matched_product fields when that response format is used.
    final source = matchedProduct.isNotEmpty ? matchedProduct : json;

    return ScanResult(
      matchType: effectiveType,
      productId: _toInt(source['product_id'] ?? source['id']),
      name: source['name']?.toString(),
      category: source['category']?.toString(),
      sellingType: source['selling_type']?.toString(),
      costPrice: _toDouble(source['cost_price']),
      pricePerUnit: _toDouble(source['price_per_unit']),
      quantity: _toDouble(source['quantity']),
      formattedQuantity: source['formatted_quantity']?.toString(),
      similarity: _toDouble(
        json['similarity'] ?? json['confidence'],
      ),
      message: json['message']?.toString(),
      candidates: candidateList,
    );
  }

  Product? toProduct() {
    if (!isProductMatch || productId == null) return null;

    return Product(
      id: productId!,
      name: name ?? '',
      category: category ?? 'General',
      sellingType: sellingType ?? 'UNIT',
      costPrice: costPrice ?? 0.0,
      pricePerUnit: pricePerUnit ?? 0.0,
      quantity: quantity ?? 0.0,
      formattedQuantity: formattedQuantity,
      isLoose: sellingType?.toUpperCase() == 'KG',
    );
  }
}