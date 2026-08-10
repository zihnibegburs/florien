import 'package:flutter/foundation.dart';

import 'dev_host.dart';

class PlatformConfig {
  static const appGroupId = 'group.com.florien.app';
  static const iosWidgetName = 'FlorienWidget';
  static const androidWidgetClass = 'com.florien.app.FlorienWidgetProvider';
  static const productionApiBaseUrl =
      'https://florien-api.onrender.com/api/v1';

  static String get apiBaseUrl {
    const envBase = String.fromEnvironment('API_BASE_URL');
    if (envBase.isNotEmpty) return envBase;
    if (!kReleaseMode &&
        devApiBaseUrl != null &&
        devApiBaseUrl!.isNotEmpty) {
      return devApiBaseUrl!;
    }
    if (kReleaseMode) return productionApiBaseUrl;

    const envHost = String.fromEnvironment('API_HOST');
    final lanHost = envHost.isNotEmpty ? envHost : devLanHost;

    if (kIsWeb) return 'http://localhost:8080/api/v1';

    if (lanHost != null && lanHost.isNotEmpty) {
      return 'http://$lanHost:8080/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080/api/v1';
      default:
        return 'http://localhost:8080/api/v1';
    }
  }

  static bool get isWeb => kIsWeb;
  static bool get isWideLayout => kIsWeb;
}
