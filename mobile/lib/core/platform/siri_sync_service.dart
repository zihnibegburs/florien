import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:florien/core/platform/widget_sync_service.dart';

class SiriSyncService {
  static const authTokenKey = 'auth_token';
  static const apiBaseUrlKey = 'api_base_url';

  /// Persists the Firebase ID token for home-widget / Siri extensions.
  /// API base URL is cleared — the Flutter app no longer uses a REST backend.
  static Future<void> syncCredentials({String? token}) async {
    if (kIsWeb || !WidgetSyncService.isAvailable) return;
    try {
      await HomeWidget.saveWidgetData<String>(apiBaseUrlKey, '');
      if (token != null && token.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>(authTokenKey, token);
      } else {
        await HomeWidget.saveWidgetData<String>(authTokenKey, '');
      }
    } catch (e) {
      debugPrint('Siri sync skipped: $e');
    }
  }
}
