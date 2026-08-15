import 'dart:io' show Platform;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:florien/core/storage/settings_storage.dart';

enum CalendarProvider { apple, google }

class CalendarConnection {
  const CalendarConnection({required this.provider, required this.detail});

  final CalendarProvider provider;
  final String detail;

  String get name => switch (provider) {
    CalendarProvider.apple => 'Apple Takvimi',
    CalendarProvider.google => 'Google Takvim',
  };
}

class CalendarConnectionService {
  CalendarConnectionService(this._settingsStorage)
    : _deviceCalendar = DeviceCalendarPlugin(),
      _googleSignIn = GoogleSignIn(scopes: const [_googleCalendarScope]);

  static const _googleCalendarScope =
      'https://www.googleapis.com/auth/calendar.readonly';

  final SettingsStorage _settingsStorage;
  final DeviceCalendarPlugin _deviceCalendar;
  final GoogleSignIn _googleSignIn;

  Future<List<CalendarConnection>> getConnections() async {
    final appleDetail = await _settingsStorage.getCalendarConnectionDetail(
      CalendarProvider.apple.name,
    );
    final googleDetail = await _settingsStorage.getCalendarConnectionDetail(
      CalendarProvider.google.name,
    );

    return [
      if (appleDetail != null)
        CalendarConnection(
          provider: CalendarProvider.apple,
          detail: appleDetail,
        ),
      if (googleDetail != null)
        CalendarConnection(
          provider: CalendarProvider.google,
          detail: googleDetail,
        ),
    ];
  }

  Future<CalendarConnection?> connect(CalendarProvider provider) =>
      switch (provider) {
        CalendarProvider.apple => _connectAppleCalendar(),
        CalendarProvider.google => _connectGoogleCalendar(),
      };

  Future<void> disconnect(CalendarProvider provider) =>
      _settingsStorage.clearCalendarConnection(provider.name);

  Future<CalendarConnection> _connectAppleCalendar() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
      throw UnsupportedError(
        'Apple Takvimi yalnızca Apple cihazlarda bağlanabilir.',
      );
    }

    var permission = await _deviceCalendar.hasPermissions();
    if (!permission.isSuccess || permission.data != true) {
      permission = await _deviceCalendar.requestPermissions();
    }
    if (!permission.isSuccess || permission.data != true) {
      throw StateError('Takvim erişimi için izin verilmedi.');
    }

    final calendars = await _deviceCalendar.retrieveCalendars();
    if (!calendars.isSuccess) {
      throw StateError('Apple takvimleri alınamadı.');
    }

    final count = calendars.data?.length ?? 0;
    final detail = count == 0
        ? 'Takvim erişimi verildi'
        : '$count takvime erişim verildi';
    await _settingsStorage.setCalendarConnectionDetail(
      CalendarProvider.apple.name,
      detail,
    );
    return CalendarConnection(provider: CalendarProvider.apple, detail: detail);
  }

  Future<CalendarConnection?> _connectGoogleCalendar() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final calendarAccessGranted = await _googleSignIn.requestScopes([
      _googleCalendarScope,
    ]);
    if (!calendarAccessGranted) {
      throw StateError('Google Takvim erişimi için izin verilmedi.');
    }

    await _settingsStorage.setCalendarConnectionDetail(
      CalendarProvider.google.name,
      account.email,
    );
    return CalendarConnection(
      provider: CalendarProvider.google,
      detail: account.email,
    );
  }
}
