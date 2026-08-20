import 'package:florien/core/storage/settings_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'migrates legacy calendar metadata into the scoped local cache',
    () async {
      SharedPreferences.setMockInitialValues({
        'imported_calendar_event_ids': ['event-1', 'event-2'],
        'calendar_connection_google': 'user@example.com',
      });
      final storage = SettingsStorage();

      expect(await storage.getImportedCalendarEventIds(), {
        'event-1',
        'event-2',
      });
      expect(
        await storage.getCalendarConnectionDetail('google'),
        'user@example.com',
      );
    },
  );
}
