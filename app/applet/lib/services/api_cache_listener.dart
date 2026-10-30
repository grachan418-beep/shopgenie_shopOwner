import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api_service.dart';

mixin ApiCacheListener<T extends StatefulWidget> on State<T> {
  bool _cacheReloadPending = false;
  bool _isReloadingFromCache = false;

  bool shouldReloadForCachedUrl(Uri url);

  Future<void> reloadFromCache();

  void startListeningForCachedData() {
    ApiService().addListener(_onCachedDataChanged);
  }

  void stopListeningForCachedData() {
    ApiService().removeListener(_onCachedDataChanged);
  }

  void _onCachedDataChanged() {
    final rawUrl = ApiService().lastUpdatedCacheUrl;
    if (rawUrl == null) return;

    final url = Uri.tryParse(rawUrl);
    if (url == null || !shouldReloadForCachedUrl(url)) return;

    _cacheReloadPending = true;
    if (!_isReloadingFromCache) {
      unawaited(_reloadUpdatedData());
    }
  }

  Future<void> _reloadUpdatedData() async {
    _isReloadingFromCache = true;
    try {
      while (_cacheReloadPending && mounted) {
        _cacheReloadPending = false;
        await reloadFromCache();
      }
    } finally {
      _isReloadingFromCache = false;
      if (_cacheReloadPending && mounted) {
        unawaited(_reloadUpdatedData());
      }
    }
  }
}
