import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopgenie_flutter/services/api_service.dart';

void main() {
  test('GET responses are cached and revalidated in the background', () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var responseCount = 0;
    final serverTask = server.forEach((request) async {
      if (request.uri.path == '/resource/') responseCount++;
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'value': responseCount}));
      await request.response.close();
    });

    final api = ApiService();
    await api.clearGetCache();
    await api.setBaseUrl('http://127.0.0.1:${server.port}');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final initial = await api.get(
      '/resource/',
      cacheKey: 'test_resource',
    ) as Map<String, dynamic>;
    final cached = await api.get(
      '/resource/',
      cacheKey: 'test_resource',
    ) as Map<String, dynamic>;
    expect(initial['value'], 1);
    expect(cached['value'], 1);

    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while ((responseCount < 2 || api.lastUpdatedCacheUrl == null) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final refreshed = await api.get(
      '/resource/',
      cacheKey: 'test_resource',
    ) as Map<String, dynamic>;
    expect(responseCount, 2);
    expect(refreshed['value'], 2);

    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'sp_api_cache_test_resource';
    expect(prefs.getKeys(), contains(cacheKey));
    final cacheEntry =
        jsonDecode(prefs.getString(cacheKey)!) as Map<String, dynamic>;
    cacheEntry['saved_at'] = DateTime.now()
        .subtract(const Duration(hours: 25))
        .millisecondsSinceEpoch;
    await prefs.setString(cacheKey, jsonEncode(cacheEntry));

    final afterExpiry = await api.get(
      '/resource/',
      cacheKey: 'test_resource',
    ) as Map<String, dynamic>;
    expect(afterExpiry['value'], 3);

    await api.clearGetCache();
    expect(
      prefs.getKeys().any((key) => key.startsWith('sp_api_cache_')),
      isFalse,
    );
    await server.close(force: true);
    await serverTask;
  });

  test('API errors do not expose backend response content', () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverTask = server.forEach((request) async {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'detail': 'internal backend details'}));
      await request.response.close();
    });

    final api = ApiService();
    await api.clearGetCache();
    await api.setBaseUrl('http://127.0.0.1:${server.port}');
    try {
      await api.get('/private/');
      fail('Expected the API request to fail.');
    } on ApiException catch (error) {
      expect(error.toString(),
          'This feature is temporarily unavailable. Please try again.');
      expect(error.toString(), isNot(contains('internal backend details')));
      expect(error.toString(), isNot(contains('127.0.0.1')));
    } finally {
      await api.clearGetCache();
      await server.close(force: true);
      await serverTask;
    }
  });

  test('shop profile and settings caches are preserved except on logout',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService();
    await api.writeCachedResponse('shop_profile', {'shop_name': 'Saved Shop'});
    await api.writeCachedResponse(
      'shop_settings',
      {'language': 'English (en)'},
    );

    await api.clearGetCache(clearShopData: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sp_api_cache_shop_profile'), isNotNull);
    expect(prefs.getString('sp_api_cache_shop_settings'), isNotNull);

    await api.clearGetCache();
    expect(prefs.getString('sp_api_cache_shop_profile'), isNull);
    expect(prefs.getString('sp_api_cache_shop_settings'), isNull);
  });
}
