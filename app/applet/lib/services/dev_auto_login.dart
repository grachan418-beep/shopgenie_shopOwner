import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class DevAutoLogin {
  static const bool _requested = bool.fromEnvironment(
    'DEV_AUTO_LOGIN',
    defaultValue: false,
  );
  static const String _role = String.fromEnvironment(
    'DEV_ROLE',
    defaultValue: 'owner',
  );
  static const String _user = String.fromEnvironment('DEV_USER');
  static const String _password = String.fromEnvironment('DEV_PASS');
  static const String _workerCode = String.fromEnvironment('DEV_WORKER_CODE');
  static const String _ownerUser = String.fromEnvironment('DEV_OWNER_USER');
  static const String _ownerPassword = String.fromEnvironment('DEV_OWNER_PASS');
  static const String _workerName = String.fromEnvironment('DEV_WORKER_NAME');

  static bool get enabled => kDebugMode && _requested;
  static bool get isBothMode => _role.trim().toLowerCase() == 'both';

  static Future<String> signIn({String? role}) async {
    if (!enabled) {
      throw StateError('Debug auto-login is disabled.');
    }

    switch ((role ?? _role).trim().toLowerCase()) {
      case 'owner':
        final username = _ownerUser.isNotEmpty ? _ownerUser : _user;
        final password = _ownerPassword.isNotEmpty ? _ownerPassword : _password;
        if (username.trim().isEmpty || password.isEmpty) {
          throw StateError(
            'Owner auto-login needs DEV_OWNER_USER and DEV_OWNER_PASS '
            '(or DEV_USER and DEV_PASS) build defines.',
          );
        }
        await AuthService().login(username, password);
        return '/dashboard';
      case 'worker':
        final name = _workerName.isNotEmpty ? _workerName : _user;
        if (name.trim().isEmpty || _workerCode.trim().isEmpty) {
          throw StateError(
            'Worker auto-login needs DEV_WORKER_NAME and DEV_WORKER_CODE '
            '(or DEV_USER and DEV_WORKER_CODE) build defines.',
          );
        }
        await AuthService().loginWorker(name, _workerCode);
        return '/worker-dashboard';
      default:
        throw StateError('DEV_ROLE must be either "owner" or "worker".');
    }
  }
}
