class User {
  final int id;
  final String username;
  final String email;
  final String? shopName;
  final String? phoneNumber;
  final String? shopCategory;
  final String? shopAddress;
  final String? ownerName;
  final bool isVerified;
  final String role; // 'OWNER' or 'WORKER'
  final int? shopId;
  final Map<String, bool> permissions;
  final DateTime? dateJoined;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.shopName,
    this.phoneNumber,
    this.shopCategory,
    this.shopAddress,
    this.ownerName,
    this.isVerified = false,
    this.role = 'OWNER',
    this.shopId,
    this.permissions = const {},
    this.dateJoined,
  });

  bool get isOwner => !isWorker;
  bool get isWorker =>
      const {'WORKER', 'SHOP_WORKER'}.contains(role.toUpperCase());

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      username: json['name'] as String? ?? json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      shopName: json['shop_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      shopCategory:
          json['shop_category'] as String? ?? json['category'] as String?,
      shopAddress:
          json['shop_address'] as String? ?? json['address'] as String?,
      ownerName: json['owner_name'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      role: json['role'] as String? ?? 'OWNER',
      shopId: json['shop_id'] as int?,
      permissions: (json['permissions'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value == true)) ??
          const {},
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(json['date_joined'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'shop_name': shopName,
      'phone_number': phoneNumber,
      'shop_category': shopCategory,
      'shop_address': shopAddress,
      'owner_name': ownerName,
      'is_verified': isVerified,
      'role': role,
      'shop_id': shopId,
      'permissions': permissions,
      'date_joined': dateJoined?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? shopName,
    String? phoneNumber,
    String? shopCategory,
    String? shopAddress,
    String? ownerName,
    bool? isVerified,
    String? role,
    int? shopId,
    Map<String, bool>? permissions,
    DateTime? dateJoined,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      shopName: shopName ?? this.shopName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      shopCategory: shopCategory ?? this.shopCategory,
      shopAddress: shopAddress ?? this.shopAddress,
      ownerName: ownerName ?? this.ownerName,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      permissions: permissions ?? this.permissions,
      dateJoined: dateJoined ?? this.dateJoined,
    );
  }
}
