import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  User? _currentUser;

  User? get currentUser {
    return _currentUser;
  }

  bool get isLoggedIn => _api.isAuthenticated;

  bool get isWorkerSession =>
      const {'WORKER', 'SHOP_WORKER'}.contains(_api.sessionRole?.toUpperCase());

  Future<User?> getCachedProfile() async {
    var response = await _api.readCachedResponse(
      'shop_profile',
      legacyPath: '/api/auth/me/',
    );
    if (response == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacyEntry = prefs.getString('sp_profile_cache');
      if (legacyEntry != null) {
        try {
          final decoded = jsonDecode(legacyEntry);
          if (decoded is Map<String, dynamic>) {
            final profile = decoded['data'] is Map<String, dynamic>
                ? decoded['data']
                : decoded;
            final savedAt = decoded['saved_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(
                    decoded['saved_at'] as int)
                : DateTime.now();
            await _api.writeCachedResponse(
              'shop_profile',
              profile,
              path: '/api/auth/me/',
              savedAt: savedAt,
            );
            response = profile;
          }
        } on FormatException {
          // Ignore an unreadable legacy entry and continue with the network.
        }
      }
    }
    if (response is! Map<String, dynamic>) return null;

    final profile = response['user'] is Map<String, dynamic>
        ? response['user'] as Map<String, dynamic>
        : response;
    _currentUser = User.fromJson(profile);
    return _currentUser;
  }

  Future<DateTime?> getCachedProfileUpdatedAt() =>
      _api.readCachedResponseUpdatedAt(
        'shop_profile',
        legacyPath: '/api/auth/me/',
      );

  Future<Map<String, dynamic>?> getCachedSettings() async {
    final response = await _api.readCachedResponse('shop_settings');
    return response is Map<String, dynamic> ? response : null;
  }

  Future<DateTime?> getCachedSettingsUpdatedAt() =>
      _api.readCachedResponseUpdatedAt('shop_settings');

  Future<void> cacheSettings(Map<String, dynamic> settings) =>
      _api.writeCachedResponse('shop_settings', settings);

  Future<AuthResponse> login(String username, String password) async {
    final response = await _api.post('/api/auth/login/',
        body: {
          'username': username.trim(),
          'password': password,
          'role': 'SHOP_OWNER',
        },
        requiresAuth: false);

    final authResponse =
        AuthResponse.fromJson(response as Map<String, dynamic>);
    if (authResponse.user?.role.toUpperCase() != 'SHOP_OWNER') {
      throw ApiException(
        'This account is not a shop owner account. Choose the matching sign-in option.',
      );
    }
    if (authResponse.access != null) {
      await _api.saveTokens(
        access: authResponse.access!,
        refresh: authResponse.refresh,
        role: 'SHOP_OWNER',
      );
      _currentUser = authResponse.user;
      await fetchProfile();
    }
    return authResponse;
  }

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    required String captchaToken,
    String? shopName,
    String? phoneNumber,
  }) async {
    final body = {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      'captcha_token': captchaToken,
      if (shopName != null && shopName.trim().isNotEmpty)
        'shop_name': shopName.trim(),
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phone_number': phoneNumber.trim(),
    };

    final response = await _api.post(
      '/api/auth/register/owner/',
      body: body,
      requiresAuth: false,
    );
    final authResponse =
        AuthResponse.fromJson(response as Map<String, dynamic>);
    if (authResponse.access != null) {
      await _api.saveTokens(
        access: authResponse.access!,
        refresh: authResponse.refresh,
        role: authResponse.user?.role ?? 'OWNER',
      );
      _currentUser = authResponse.user;
      await fetchProfile();
    }
    return authResponse;
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _api.post(
      '/api/auth/email-verification/confirm/',
      body: {'email': email.trim(), 'code': code.trim()},
      requiresAuth: false,
    );
    if (response is! Map<String, dynamic>) {
      throw ApiException(
          'The server returned an invalid verification response.');
    }
  }

  Future<void> resendVerification({
    required String email,
    required String captchaToken,
  }) async {
    final response = await _api.post(
      '/api/auth/email-verification/resend/',
      body: {'email': email.trim(), 'captcha_token': captchaToken},
      requiresAuth: false,
    );
    if (response is! Map<String, dynamic>) {
      throw ApiException('The server returned an invalid resend response.');
    }
  }

  Future<AuthResponse> loginWorker(String name, String code) async {
    final response = await _api.post(
      '/api/auth/worker-login/',
      body: {'name': name.trim(), 'code': code.trim()},
      requiresAuth: false,
    );
    final authResponse =
        AuthResponse.fromJson(response as Map<String, dynamic>);
    if (authResponse.user?.role.toUpperCase() != 'SHOP_WORKER') {
      throw ApiException(
        'The server did not start a shopkeeper session.',
      );
    }
    if (authResponse.access != null) {
      await _api.saveTokens(
        access: authResponse.access!,
        refresh: authResponse.refresh,
        role: 'WORKER',
      );
      _currentUser = authResponse.user;
      await fetchProfile();
    }
    return authResponse;
  }

  Future<User?> fetchProfile() async {
    final response = await _api.get(
      '/api/auth/me/',
      cacheKey: 'shop_profile',
    );
    if (response is! Map<String, dynamic>) {
      throw ApiException('The server returned an invalid profile response.');
    }
    _currentUser = User.fromJson(response);
    return _currentUser;
  }

  Future<Map<String, dynamic>> updateShopProfile(
    Map<String, dynamic> profile,
  ) async {
    final response = await _api.patch(
      '/api/shops/my_shop/',
      body: profile,
    );
    if (response is! Map<String, dynamic>) {
      throw ApiException(
          'The server returned an invalid shop profile response.');
    }
    return response;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _api.clearAuth();
  }
}
