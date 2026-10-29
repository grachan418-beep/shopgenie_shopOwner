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

  Future<AuthResponse> login(String username, String password) async {
    final response = await _api.post('/api/auth/login/',
        body: {
          'username': username.trim(),
          'password': password,
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
        role: authResponse.user?.role ?? 'OWNER',
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
    String? shopName,
    String? phoneNumber,
  }) async {
    final body = {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      if (shopName != null && shopName.trim().isNotEmpty)
        'shop_name': shopName.trim(),
    };

    final response = await _api.post(
      '/api/auth/register/owner/',
      body: body,
      requiresAuth: false,
    );
    final authResponse =
        AuthResponse.fromJson(response as Map<String, dynamic>);
    if (authResponse.user?.role.toUpperCase() != 'SHOP_OWNER') {
      throw ApiException('Owner registration did not create an owner account.');
    }
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
    final response = await _api.get('/api/auth/me/');
    if (response is! Map<String, dynamic>) {
      throw ApiException('The server returned an invalid profile response.');
    }
    _currentUser = User.fromJson(response);
    return _currentUser;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _api.clearAuth();
  }
}
