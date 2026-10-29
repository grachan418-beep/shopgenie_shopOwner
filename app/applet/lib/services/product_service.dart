import '../models/product.dart';
import 'api_service.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final ApiService _api = ApiService();

  Future<List<Product>> getProducts() async {
    final products = <Product>[];
    var page = 1;
    while (true) {
      final response = await _api.get(
        '/api/products/',
        queryParams: {'page': page},
      );
      final results = response is Map<String, dynamic>
          ? response['results']
          : response;
      if (results is! List) {
        throw ApiException('The server returned an invalid product list.');
      }
      products.addAll(
        results.map((item) => Product.fromJson(item as Map<String, dynamic>)),
      );
      if (response is! Map<String, dynamic> ||
          response['next'] == null ||
          results.isEmpty) {
        return products;
      }
      page++;
    }
  }

  Future<Product> getProductDetail(int id) async {
    final response = await _api.get('/api/products/$id/');
    return Product.fromJson(response as Map<String, dynamic>);
  }

  Future<Product> registerProduct({
    required String name,
    required String category,
    required String sellingType,
    required double costPrice,
    required double pricePerUnit,
    required double quantity,
    required bool isLoose,
    List<double>? featureVector,
    String? imageUrl,
  }) async {
    final shopResponse = await _api.get('/api/shops/my_shop/');
    if (shopResponse is! Map<String, dynamic> ||
        shopResponse['id'] is! num) {
      throw ApiException('The server did not return this owner’s shop.');
    }
    final unit = _backendUnit(sellingType, isLoose: isLoose);
    final body = {
      'shop': (shopResponse['id'] as num).toInt(),
      'name': name.trim(),
      'category': category.trim(),
      'description': '',
      'brand': '',
      'size': '',
      'unit': unit,
      'status': 'PUBLISHED',
      'cost_price': costPrice,
      'mrp': pricePerUnit,
      'selling_price': pricePerUnit,
      'stock_quantity': quantity,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
    };

    final response = await _api.post('/api/products/', body: body);
    return Product.fromJson(response as Map<String, dynamic>);
  }

  Future<Product> updateProduct(
    int id, {
    String? name,
    String? category,
    String? sellingType,
    double? costPrice,
    double? pricePerUnit,
    double? quantity,
    bool? isLoose,
    List<double>? featureVector,
    String? imageUrl,
  }) async {
    final currentProduct =
        quantity == null ? null : await getProductDetail(id);
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (category != null) body['category'] = category.trim();
    if (sellingType != null) {
      body['unit'] = _backendUnit(sellingType, isLoose: isLoose ?? false);
    }
    if (costPrice != null) body['cost_price'] = costPrice;
    if (pricePerUnit != null) {
      body['selling_price'] = pricePerUnit;
      body['mrp'] = pricePerUnit;
    }
    if (imageUrl != null) body['image_url'] = imageUrl;

    if (body.isNotEmpty) {
      await _api.patch('/api/products/$id/', body: body);
    }
    if (quantity != null && quantity != currentProduct!.quantity) {
      await _recordStockAdjustment(
        id,
        quantity - currentProduct.quantity,
      );
    }
    return getProductDetail(id);
  }

  Future<Product> updateStockQuantity(int id, double quantity) async {
    final product = await getProductDetail(id);
    final delta = quantity - product.quantity;
    if (delta == 0) return product;
    await _recordStockAdjustment(id, delta);
    return getProductDetail(id);
  }

  Future<void> _recordStockAdjustment(int productId, double delta) async {
    await _api.post(
      '/api/inventory/',
      body: {
        'product': productId,
        'delta': delta,
        'reason': 'CORRECTION',
        'note': 'Stock count correction',
      },
    );
  }

  Future<void> deleteProduct(int id) async {
    await _api.delete('/api/products/$id/');
  }

  String _backendUnit(String sellingType, {required bool isLoose}) {
    if (isLoose || sellingType.toUpperCase() == 'KG') return 'KG';
    if (sellingType.toUpperCase() == 'LITER') return 'LITER';
    return 'PIECE';
  }
}
