import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String keyBaseUrl = 'sp_api_base_url';
  static const String keyAccessToken = 'sp_access_token';
  static const String keyRefreshToken = 'sp_refresh_token';
  static const String keySessionRole = 'sp_session_role';
  static const String keyEsp32Url = 'sp_esp32_cam_url';

  // USB-debugging default; use 10.0.2.2 explicitly for Android emulators.
  // Usage: flutter run --dart-define=BASE_URL=http://YOUR_HOST:8000
  static const String configuredBaseUrl = String.fromEnvironment('BASE_URL');
  static const String defaultBaseUrl =
      configuredBaseUrl != '' ? configuredBaseUrl : 'http://127.0.0.1:8000';
  static const String defaultEsp32Url = 'http://192.168.1.100:81/stream';

  String _baseUrl = defaultBaseUrl;
  String? _accessToken;
  String? _refreshToken;
  String _esp32Url = defaultEsp32Url;
  String? _sessionRole;
  Future<void> Function()? onAuthenticationExpired;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  String get baseUrl => _baseUrl;
  String get esp32Url => _esp32Url;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  String? get token => _accessToken;
  String? get sessionRole => _sessionRole;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString(keyBaseUrl);
    _baseUrl = configuredBaseUrl.isNotEmpty
        ? defaultBaseUrl
        : savedBaseUrl ?? defaultBaseUrl;
    _sessionRole = prefs.getString(keySessionRole);
    _accessToken = await _secureStorage.read(key: keyAccessToken);
    _refreshToken = await _secureStorage.read(key: keyRefreshToken);
    if (_accessToken == null) {
      _accessToken = prefs.getString(keyAccessToken);
      if (_accessToken != null) {
        await _secureStorage.write(key: keyAccessToken, value: _accessToken);
        await prefs.remove(keyAccessToken);
      }
    }
    if (_refreshToken == null) {
      _refreshToken = prefs.getString(keyRefreshToken);
      if (_refreshToken != null) {
        await _secureStorage.write(key: keyRefreshToken, value: _refreshToken);
        await prefs.remove(keyRefreshToken);
      }
    }
    if (_accessToken != null && _sessionRole == null) {
      _sessionRole = 'OWNER';
      await prefs.setString(keySessionRole, _sessionRole!);
    }
    _esp32Url = prefs.getString(keyEsp32Url) ?? defaultEsp32Url;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = _normalizeBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBaseUrl, _baseUrl);
  }

  Future<void> testConnection(String url) async {
    final previousBaseUrl = _baseUrl;
    _baseUrl = _normalizeBaseUrl(url);
    try {
      await get('/api/shops/', requiresAuth: false).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw ApiException(
          'Connection to $_baseUrl timed out. Check USB forwarding or that your phone and computer share a network.',
        ),
      );
    } finally {
      _baseUrl = previousBaseUrl;
    }
  }

  String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.path.isNotEmpty && uri.path != '/') {
      throw ApiException(
        'Enter a backend origin such as http://127.0.0.1:8000 without an /api path.',
      );
    }
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  Future<void> setEsp32Url(String url) async {
    _esp32Url = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyEsp32Url, _esp32Url);
  }

  Future<void> saveTokens({
    required String access,
    String? refresh,
    String role = 'OWNER',
  }) async {
    _accessToken = access;
    _sessionRole = role.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySessionRole, _sessionRole!);
    await _secureStorage.write(key: keyAccessToken, value: access);
    if (refresh != null) {
      _refreshToken = refresh;
      await _secureStorage.write(key: keyRefreshToken, value: refresh);
    } else {
      _refreshToken = null;
      await _secureStorage.delete(key: keyRefreshToken);
    }
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyRefreshToken);
  }

  Future<void> clearAuth() async {
    _accessToken = null;
    _refreshToken = null;
    _sessionRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyRefreshToken);
    await prefs.remove(keySessionRole);
    await _secureStorage.delete(key: keyAccessToken);
    await _secureStorage.delete(key: keyRefreshToken);
  }

  Map<String, String> _headers({bool requiresAuth = true}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _accessToken != null) {
      map['Authorization'] = 'Bearer $_accessToken';
    }
    return map;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    String fullUrl = '$_baseUrl${path.startsWith('/') ? path : '/$path'}';
    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams =
          queryParameters.map((key, value) => MapEntry(key, value.toString()));
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  String _formatNetworkError(dynamic e) {
    if (e is SocketException) {
      return 'Failed to connect to $_baseUrl. The backend server is not running or unreachable from this network environment. Verify that the Django server is started and accessible at this address.';
    } else if (e is HttpException) {
      return 'HTTP error while communicating with $_baseUrl: ${e.message}';
    } else if (e is FormatException) {
      return 'Malformed response or URL address: $_baseUrl';
    }
    final str = e.toString();
    if (str.contains('Failed host lookup') ||
        str.contains('Connection refused') ||
        str.contains('Failed to connect')) {
      return 'Failed to connect to $_baseUrl. Server is offline or unreachable.';
    }
    return 'Network error: $str';
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParams, bool requiresAuth = true}) async {
    try {
      final uri = _buildUri(path, queryParams);
      final response = await _sendWithRefresh(
        () => http.get(uri, headers: _headers(requiresAuth: requiresAuth)),
        allowRefresh: requiresAuth,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw ApiException(
          'Connection to $_baseUrl timed out after 10s. The server may be unresponsive.',
        ),
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_formatNetworkError(e));
    }
  }

  Future<dynamic> post(String path,
      {dynamic body, bool requiresAuth = true}) async {
    try {
      final uri = _buildUri(path);
      final response = await _sendWithRefresh(
        () => http.post(
          uri,
          headers: _headers(requiresAuth: requiresAuth),
          body: body != null ? jsonEncode(body) : null,
        ),
        allowRefresh: requiresAuth,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw ApiException(
          'Connection to $_baseUrl timed out after 15s. The server may be unresponsive.',
        ),
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_formatNetworkError(e));
    }
  }

  Future<dynamic> put(String path,
      {dynamic body, bool requiresAuth = true}) async {
    try {
      final uri = _buildUri(path);
      final response = await _sendWithRefresh(
        () => http.put(
          uri,
          headers: _headers(requiresAuth: requiresAuth),
          body: body != null ? jsonEncode(body) : null,
        ),
        allowRefresh: requiresAuth,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw ApiException(
          'Connection to $_baseUrl timed out after 15s. The server may be unresponsive.',
        ),
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_formatNetworkError(e));
    }
  }

  Future<dynamic> patch(String path,
      {dynamic body, bool requiresAuth = true}) async {
    try {
      final uri = _buildUri(path);
      final response = await _sendWithRefresh(
        () => http.patch(
          uri,
          headers: _headers(requiresAuth: requiresAuth),
          body: body != null ? jsonEncode(body) : null,
        ),
        allowRefresh: requiresAuth,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw ApiException(
          'Connection to $_baseUrl timed out after 15s. The server may be unresponsive.',
        ),
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_formatNetworkError(e));
    }
  }

  Future<dynamic> delete(String path, {bool requiresAuth = true}) async {
    try {
      final uri = _buildUri(path);
      final response = await _sendWithRefresh(
        () => http.delete(uri, headers: _headers(requiresAuth: requiresAuth)),
        allowRefresh: requiresAuth,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw ApiException(
          'Connection to $_baseUrl timed out after 10s. The server may be unresponsive.',
        ),
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_formatNetworkError(e));
    }
  }

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() send, {
    required bool allowRefresh,
  }) async {
    final response = await send();
    if (!allowRefresh ||
        response.statusCode != 401 ||
        _accessToken == null ||
        _refreshToken == null) {
      return response;
    }

    final refreshResponse = await http.post(
      _buildUri('/api/auth/refresh/'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'refresh': _refreshToken}),
    );
    if (refreshResponse.statusCode < 200 || refreshResponse.statusCode >= 300) {
      return response;
    }

    final decoded = jsonDecode(refreshResponse.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['access'] is! String ||
        (decoded['access'] as String).isEmpty) {
      throw ApiException(
          'The backend returned an invalid token refresh response.');
    }
    await saveTokens(
      access: decoded['access'] as String,
      refresh: decoded['refresh'] as String? ?? _refreshToken,
      role: _sessionRole ?? 'OWNER',
    );
    return send();
  }

  Future<dynamic> _processResponse(http.Response response) async {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (response.statusCode == 401 && _accessToken != null) {
      await clearAuth();
      await onAuthenticationExpired?.call();
    }

    String errorMessage = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('error')) {
        errorMessage = decoded['error'].toString();
      } else if (decoded.containsKey('detail')) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic> && detail['error'] != null) {
          errorMessage = detail['error'].toString();
        } else {
          errorMessage = detail.toString();
        }
      } else if (decoded.containsKey('message')) {
        errorMessage = decoded['message'].toString();
      } else {
        // Collect field errors
        final errors =
            decoded.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        if (errors.isNotEmpty) errorMessage = errors;
      }
    }

    throw ApiException(errorMessage,
        statusCode: response.statusCode, data: decoded);
  }
}
