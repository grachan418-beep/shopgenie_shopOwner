import '../models/analytics.dart';
import '../models/invoice.dart';
import 'api_service.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  final ApiService _api = ApiService();

  Future<List<Invoice>> getInvoices() async {
    final response = await _api.get('/api/billing/');
    final results =
        response is Map<String, dynamic> ? response['results'] : response;
    if (results is! List) {
      throw ApiException('The server returned an invalid invoice list.');
    }
    return results
        .map((item) => Invoice.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Invoice> getInvoiceDetail(int id) async {
    final response = await _api.get('/api/billing/$id/');
    return Invoice.fromJson(response as Map<String, dynamic>);
  }

  Future<ShopAnalytics> getAnalytics() async {
    final response = await _api.get(
      '/api/shops/dashboard/',
      cacheKey: 'business_overview',
    );
    if (response is! Map<String, dynamic>) {
      throw ApiException('The server returned invalid dashboard analytics.');
    }
    return ShopAnalytics.fromJson(response);
  }

  Future<ShopAnalytics?> getCachedAnalytics() async {
    final response = await _api.readCachedResponse(
      'business_overview',
      legacyPath: '/api/shops/dashboard/',
    );
    if (response is! Map<String, dynamic>) return null;
    return ShopAnalytics.fromJson(response);
  }
}
