import 'user.dart';

class AuthResponse {
  final String? message;
  final String? access;
  final String? refresh;
  final User? user;

  AuthResponse({
    this.message,
    this.access,
    this.refresh,
    this.user,
  });

  String? get accessToken => access;
  String? get refreshToken => refresh;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    String? acc = json['access'] as String?;
    String? ref = json['refresh'] as String?;

    if (json.containsKey('tokens') && json['tokens'] is Map<String, dynamic>) {
      final tokens = json['tokens'] as Map<String, dynamic>;
      acc ??= tokens['access'] as String?;
      ref ??= tokens['refresh'] as String?;
    }

    return AuthResponse(
      message: json['message'] as String?,
      access: acc,
      refresh: ref,
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
