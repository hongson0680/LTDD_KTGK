import 'package:flutter/foundation.dart';

const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String get defaultApiBaseUrl {
  if (_configuredBaseUrl.trim().isNotEmpty) {
    return _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  if (kReleaseMode) return '';
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:9902';
  }
  return 'http://localhost:9902';
}
