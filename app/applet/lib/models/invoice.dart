
import 'invoice_item.dart';

class Invoice {
  final int id;
  final int? user;
  final double totalAmount;
  final String status;
  final List<InvoiceItem> items;
  final int itemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Invoice({
    required this.id,
    this.user,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.itemCount,
    this.createdAt,
    this.updatedAt,
  });

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

  factory Invoice.fromJson(Map<String, dynamic> json) {
    List<InvoiceItem> itemsList = [];

    final rawItems = json['items'];

    if (rawItems is List) {
      itemsList = rawItems
          .whereType<Map<String, dynamic>>()
          .map(InvoiceItem.fromJson)
          .toList();
    }

    final rawCreatedAt = json['created_at'];
    final rawUpdatedAt = json['updated_at'];

    return Invoice(
      id: _toInt(json['id']) ?? 0,
      user: _toInt(json['user']),
      totalAmount: _toDouble(json['total_amount']),
      status: json['status']?.toString() ?? 'COMPLETED',
      items: itemsList,
      itemCount: _toInt(json['item_count']) ?? itemsList.length,
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
      'total_amount': totalAmount,
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
      'item_count': itemCount,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}