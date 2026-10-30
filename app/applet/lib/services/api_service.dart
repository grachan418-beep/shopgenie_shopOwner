import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

class _CachedApiResponse {
  final dynamic data;
  final DateTime savedAt;

  const _CachedApiResponse(this.data, this.savedAt);
}

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String keyBaseUrl = 'sp_api_base_url';
  static const String keyAccessToken = 'sp_access_token';
  static const String keyRefreshToken = 'sp_refresh_token';
  static const String keySessionRole = 'sp_session_role';
  static const String keyEsp32Url = 'sp_esp32_cam_url';
  static const String _cacheKeyPrefix = 'sp_api_cache_';
  static const String _legacyCacheKeyPrefix = 'sp_api_get_cache_';
  static const Duration _cacheLifetime = Duration(hours: 24);
  static const Duration _refreshCooldown = Duration(seconds: 5);

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
  bool? _isBackendAvailable;
  Timer? _connectionCheckTimer;
  bool _isCheckingConnection = false;
  final Map<String, DateTime> _cacheRefreshStartedAt = {};
  final Map<String, Future<dynamic>> _cacheRequestsInProgress = {};
  int _cacheGeneration = 0;
  String? _lastUpdatedCacheKey;
  String? _lastUpdatedCacheUrl;
  Future<void> Function()? onAuthenticationExpired;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  String get baseUrl => _baseUrl;
  bool? get isBackendAvailable => _isBackendAvailable;
  String? get lastUpdatedCacheKey => _lastUpdatedCacheKey;
  String? get lastUpdatedCacheUrl => _lastUpdatedCacheUrl;
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
    await clearGetCache(clearShopData: false);
    unawaited(checkBackendConnection());
  }

  void startConnectionMonitoring() {
    if (_connectionCheckTimer != null) return;
    unawaited(checkBackendConnection());
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(checkBackendConnection()),
    );
  }

  Future<void> checkBackendConnection() async {
    if (_isCheckingConnection) return;
    _isCheckingConnection = true;
    try {
      await http
          .get(_buildUri('/api/shops/'))
          .timeout(const Duration(seconds: 5));
      _setBackendAvailability(true, refreshCachedData: true);
    } catch (_) {
      _setBackendAvailability(false);
    } finally {
      _isCheckingConnection = false;
    }
  }

  void _setBackendAvailability(
    bool isAvailable, {
    bool refreshCachedData = false,
  }) {
    if (_isBackendAvailable == isAvailable) return;
    _isBackendAvailable = isAvailable;
    _lastUpdatedCacheKey = null;
    _lastUpdatedCacheUrl = null;
    notifyListeners();
    if (isAvailable && refreshCachedData) {
      unawaited(_refreshAllCachedResponses());
    }
  }

  Future<void> testConnection(String url) async {
    final previousBaseUrl = _baseUrl;
    _baseUrl = _normalizeBaseUrl(url);
    try {
      await get('/api/shops/', requiresAuth: false, forceRefresh: true).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw ApiException(
          'Could not connect right now. Please try again.',
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
    if (_accessToken != access || _sessionRole != role.toUpperCase()) {
      await clearGetCache(clearShopData: false);
    }
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
    await clearGetCache();
  }

  Future<void> clearGetCache({bool clearShopData = true}) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
          (key) =>
              (key.startsWith(_cacheKeyPrefix) &&
                  (clearShopData ||
                      !const {
                        'shop_profile',
                        'shop_settings',
                      }.contains(key.substring(_cacheKeyPrefix.length)))) ||
              (clearShopData && key.startsWith(_legacyCacheKeyPrefix)) ||
              (clearShopData && key == 'sp_profile_cache') ||
              key == 'sp_dashboard_analytics_cache',
        )) {
      await prefs.remove(key);
    }
    _cacheRefreshStartedAt.clear();
    _cacheRequestsInProgress.clear();
    _cacheGeneration++;
    _lastUpdatedCacheKey = null;
    _lastUpdatedCacheUrl = null;
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

  String _formatNetworkError() {
    return 'You appear to be offline. Please try again when your connection returns.';
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
    bool forceRefresh = false,
    String? cacheKey,
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final stableCacheKey = _getCacheKey(uri, cacheKey: cacheKey);
      final cachedResponse = forceRefresh
          ? null
          : await _readCachedResponse(
              stableCacheKey,
              legacyUri: uri,
              requiresAuth: requiresAuth,
            );
      if (cachedResponse != null) {
        debugPrint('[api-cache] cache hit: $stableCacheKey');
        _scheduleCachedResponseRefresh(
          stableCacheKey,
          uri,
          requiresAuth: requiresAuth,
        );
        return cachedResponse.data;
      }

      debugPrint('[api-cache] cache miss: $stableCacheKey');
      return await _fetchAndCacheResponse(
        stableCacheKey,
        uri,
        requiresAuth: requiresAuth,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _setBackendAvailability(false);
      throw ApiException(_formatNetworkError());
    }
  }

  String _getCacheKey(Uri uri, {String? cacheKey}) {
    if (cacheKey != null && cacheKey.trim().isNotEmpty) {
      return cacheKey.trim();
    }

    final normalizedUri = uri.replace(
      queryParameters: Map.fromEntries(
        uri.queryParameters.entries.toList()
          ..sort((first, second) => first.key.compareTo(second.key)),
      ),
    );
    return base64Url
        .encode(utf8.encode(normalizedUri.toString()))
        .replaceAll('=', '');
  }

  Future<dynamic> readCachedResponse(
    String cacheKey, {
    String? legacyPath,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    final legacyUri =
        legacyPath == null ? null : _buildUri(legacyPath, queryParams);
    final response = await _readCachedResponse(
      cacheKey,
      legacyUri: legacyUri,
      requiresAuth: requiresAuth,
    );
    if (response == null) {
      debugPrint('[api-cache] cache miss: $cacheKey');
      return null;
    }
    debugPrint('[api-cache] cache hit: $cacheKey');
    return response.data;
  }

  Future<DateTime?> readCachedResponseUpdatedAt(
    String cacheKey, {
    String? legacyPath,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    final legacyUri =
        legacyPath == null ? null : _buildUri(legacyPath, queryParams);
    final response = await _readCachedResponse(
      cacheKey,
      legacyUri: legacyUri,
      requiresAuth: requiresAuth,
    );
    return response?.savedAt;
  }

  Future<void> writeCachedResponse(
    String cacheKey,
    dynamic data, {
    String? path,
    bool requiresAuth = true,
    DateTime? savedAt,
  }) async {
    final uri = path == null ? null : _buildUri(path);
    final storedAt = savedAt ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(cacheKey),
      jsonEncode({
        'saved_at': storedAt.millisecondsSinceEpoch,
        'url': uri?.toString(),
        'cache_key': cacheKey,
        'requires_auth': requiresAuth,
        'role': _sessionRole,
        'data': data,
      }),
    );
    debugPrint('[api-cache] cache write: $cacheKey');
  }

  Future<_CachedApiResponse?> _readCachedResponse(
    String cacheKey, {
    Uri? legacyUri,
    bool requiresAuth = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _storageKey(cacheKey);
    var encoded = prefs.getString(storageKey);
    var resolvedStorageKey = storageKey;
    if (encoded == null && legacyUri != null) {
      final scope = requiresAuth ? (_sessionRole ?? 'authenticated') : 'public';
      final oldKey = base64Url
          .encode(utf8.encode('$_baseUrl|$scope|$legacyUri'))
          .replaceAll('=', '');
      resolvedStorageKey = '$_legacyCacheKeyPrefix$oldKey';
      encoded = prefs.getString(resolvedStorageKey);
      if (encoded != null) {
        debugPrint('[api-cache] cache hit: $cacheKey (migrating saved entry)');
      }
    }
    if (encoded == null) return null;

    dynamic entry;
    try {
      entry = jsonDecode(encoded);
    } on FormatException {
      await prefs.remove(resolvedStorageKey);
      return null;
    }
    if (entry is! Map<String, dynamic> ||
        entry['saved_at'] is! int ||
        !entry.containsKey('data')) {
      await prefs.remove(resolvedStorageKey);
      return null;
    }

    final savedAt =
        DateTime.fromMillisecondsSinceEpoch(entry['saved_at'] as int);
    if (DateTime.now().difference(savedAt) > _cacheLifetime &&
        cacheKey != 'shop_profile' &&
        cacheKey != 'shop_settings') {
      await prefs.remove(resolvedStorageKey);
      return null;
    }
    if (resolvedStorageKey != storageKey) {
      await prefs.setString(
        storageKey,
        jsonEncode({
          ...entry,
          'cache_key': cacheKey,
          'url': legacyUri!.toString(),
          'requires_auth': requiresAuth,
          'role': _sessionRole,
        }),
      );
      await prefs.remove(resolvedStorageKey);
    }
    return _CachedApiResponse(entry['data'], savedAt);
  }

  String _storageKey(String cacheKey) => '$_cacheKeyPrefix$cacheKey';

  void _scheduleCachedResponseRefresh(
    String cacheKey,
    Uri uri, {
    required bool requiresAuth,
  }) {
    final now = DateTime.now();
    final lastStarted = _cacheRefreshStartedAt[cacheKey];
    if (lastStarted != null && now.difference(lastStarted) < _refreshCooldown) {
      return;
    }
    _cacheRefreshStartedAt[cacheKey] = now;
    unawaited(
      _fetchAndCacheResponse(
        cacheKey,
        uri,
        requiresAuth: requiresAuth,
        notifyCacheUpdate: true,
      ).catchError((Object _) {
        return null;
      }),
    );
  }

  Future<dynamic> _fetchAndCacheResponse(
    String cacheKey,
    Uri uri, {
    required bool requiresAuth,
    bool notifyCacheUpdate = false,
  }) async {
    final inProgress = _cacheRequestsInProgress[cacheKey];
    if (inProgress != null) return inProgress;

    final generation = _cacheGeneration;
    final request = _performFetchAndCacheResponse(
      cacheKey,
      uri,
      requiresAuth: requiresAuth,
      notifyCacheUpdate: notifyCacheUpdate,
      generation: generation,
    );
    _cacheRequestsInProgress[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_cacheRequestsInProgress[cacheKey], request)) {
        _cacheRequestsInProgress.remove(cacheKey);
      }
    }
  }

  Future<dynamic> _performFetchAndCacheResponse(
    String cacheKey,
    Uri uri, {
    required bool requiresAuth,
    required bool notifyCacheUpdate,
    required int generation,
  }) async {
    try {
      final response = await _sendWithRefresh(
        () => http.get(uri, headers: _headers(requiresAuth: requiresAuth)),
        allowRefresh: requiresAuth,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _setBackendAvailability(false);
          throw ApiException(
            'You appear to be offline. Please try again when your connection returns.',
          );
        },
      );
      final data = await _processResponse(response);
      if (generation != _cacheGeneration) return data;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey(cacheKey),
        jsonEncode({
          'saved_at': DateTime.now().millisecondsSinceEpoch,
          'url': uri.toString(),
          'cache_key': cacheKey,
          'requires_auth': requiresAuth,
          'role': _sessionRole,
          'data': data,
        }),
      );
      debugPrint('[api-cache] cache write: $cacheKey');
      if (notifyCacheUpdate) {
        _cacheRefreshStartedAt[cacheKey] = DateTime.now();
        _lastUpdatedCacheKey = cacheKey;
        _lastUpdatedCacheUrl = uri.toString();
        notifyListeners();
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (error) {
      _setBackendAvailability(false);
      throw ApiException(_formatNetworkError());
    }
  }

  Future<void> _refreshAllCachedResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_cacheKeyPrefix))
        .toList();

    final refreshes = <Future<void>>[];
    for (final storageKey in storageKeys) {
      final encoded = prefs.getString(storageKey);
      if (encoded == null) continue;

      dynamic entry;
      try {
        entry = jsonDecode(encoded);
      } on FormatException {
        await prefs.remove(storageKey);
        continue;
      }
      if (entry is! Map<String, dynamic> ||
          entry['url'] is! String ||
          entry['requires_auth'] is! bool ||
          ((entry['requires_auth'] as bool) && entry['role'] != _sessionRole)) {
        continue;
      }

      final uri = Uri.tryParse(entry['url'] as String);
      if (uri == null || uri.origin != _baseUrl) continue;
      final cacheKey = entry['cache_key'] is String
          ? entry['cache_key'] as String
          : storageKey.substring(_cacheKeyPrefix.length);
      refreshes.add(
        _fetchAndCacheResponse(
          cacheKey,
          uri,
          requiresAuth: entry['requires_auth'] as bool,
          notifyCacheUpdate: true,
        ).then<void>((_) {}).catchError((Object _) {}),
      );
    }
    await Future.wait(refreshes);
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
        onTimeout: () {
          _setBackendAvailability(false);
          throw ApiException(
            'You appear to be offline. Please try again when your connection returns.',
          );
        },
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      _setBackendAvailability(false);
      throw ApiException(_formatNetworkError());
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
        onTimeout: () {
          _setBackendAvailability(false);
          throw ApiException(
            'You appear to be offline. Please try again when your connection returns.',
          );
        },
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      _setBackendAvailability(false);
      throw ApiException(_formatNetworkError());
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
        onTimeout: () {
          _setBackendAvailability(false);
          throw ApiException(
            'You appear to be offline. Please try again when your connection returns.',
          );
        },
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      _setBackendAvailability(false);
      throw ApiException(_formatNetworkError());
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
        onTimeout: () {
          _setBackendAvailability(false);
          throw ApiException(
            'You appear to be offline. Please try again when your connection returns.',
          );
        },
      );
      return await _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      _setBackendAvailability(false);
      throw ApiException(_formatNetworkError());
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
    _setBackendAvailability(true, refreshCachedData: true);
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

    final errorMessage = switch (response.statusCode) {
      400 => 'Please check the information and try again.',
      401 => 'Your sign-in details could not be verified.',
      403 => 'You do not have permission to do that.',
      404 => 'That information is no longer available.',
      >= 500 => 'This feature is temporarily unavailable. Please try again.',
      _ => 'Something went wrong. Please try again.',
    };

    throw ApiException(errorMessage,
        statusCode: response.statusCode, data: decoded);
  }
}
