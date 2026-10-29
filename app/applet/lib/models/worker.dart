class Worker {
  final int id;
  final String name;
  final String phone;
  final Map<String, bool> permissions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.permissions,
    required this.isActive,
    this.createdAt,
    this.lastLoginAt,
  });

  factory Worker.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    final rawId = json['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0;
    return Worker(
      id: id,
      name: json['name']?.toString() ??
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      phone: json['phone']?.toString() ?? '',
      permissions: rawPermissions is Map<String, dynamic>
          ? rawPermissions.map((key, value) => MapEntry(key, value == true))
          : {
              'view_products': json['can_view_products'] == true,
              'manage_inventory': json['can_manage_inventory'] == true,
              'create_bills': json['can_confirm_bills'] == true,
              'view_invoices': json['can_view_invoices'] == true,
            },
      isActive: json['is_active'] as bool? ??
          json['is_worker_active'] as bool? ??
          false,
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['date_joined'])?.toString() ?? '',
      ),
      lastLoginAt: DateTime.tryParse(json['last_login_at']?.toString() ?? ''),
    );
  }
}

class CreatedWorker {
  final Worker worker;
  final String code;

  const CreatedWorker({required this.worker, required this.code});

  factory CreatedWorker.fromJson(Map<String, dynamic> json) {
    final workerJson = json['worker'];
    return CreatedWorker(
      worker: Worker.fromJson(
        workerJson is Map<String, dynamic> ? workerJson : json,
      ),
      code: json['code'] as String,
    );
  }
}
