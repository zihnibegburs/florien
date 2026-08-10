import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:florien/core/theme/florien_theme.dart';

class CalendarImportEvent {
  const CalendarImportEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.calendarName,
    required this.color,
    required this.allDay,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String calendarName;
  final String color;
  final bool allDay;
}

enum CalendarImportRange { today, thisWeek, next7Days }

class CalendarImportService {
  CalendarImportService({DeviceCalendarPlugin? plugin}) : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  Future<bool> ensurePermissions() async {
    final granted = await _plugin.hasPermissions();
    if (granted.isSuccess && granted.data == true) return true;

    final requested = await _plugin.requestPermissions();
    return requested.isSuccess && requested.data == true;
  }

  Future<List<Calendar>> retrieveCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return [];
    return result.data!.where((calendar) => calendar.isReadOnly != true).toList();
  }

  Future<List<CalendarImportEvent>> retrieveEvents({
    required Map<String, Calendar> calendarsById,
    required List<String> calendarIds,
    required CalendarImportRange range,
    required Set<String> importedIds,
  }) async {
    final now = DateTime.now();
    final (startDate, endDate) = _rangeDates(range, now);
    final events = <CalendarImportEvent>[];

    for (var i = 0; i < calendarIds.length; i++) {
      final calendarId = calendarIds[i];
      final calendar = calendarsById[calendarId];
      if (calendar == null) continue;

      final calendarEvents = await _retrieveEventsForCalendar(calendarId, startDate, endDate);
      for (final event in calendarEvents) {
        final mapped = _mapEvent(
          event,
          calendarName: calendar.name ?? calendar.accountName ?? calendarId,
          color: colorForCalendarIndex(i),
          importedIds: importedIds,
        );
        if (mapped != null) events.add(mapped);
      }
    }

    events.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return events;
  }

  Future<List<Event>> _retrieveEventsForCalendar(
    String calendarId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final events = <Event>[];
    const chunkYears = 4;
    var chunkStart = DateTime(startDate.year, startDate.month, startDate.day);

    while (!chunkStart.isAfter(endDate)) {
      final chunkEndYear = chunkStart.year + chunkYears;
      var chunkEnd = DateTime(chunkEndYear, endDate.month, endDate.day, 23, 59, 59);
      if (chunkEnd.isAfter(endDate)) chunkEnd = endDate;

      final result = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: chunkStart, endDate: chunkEnd),
      );
      if (result.isSuccess && result.data != null) {
        events.addAll(result.data!);
      }

      chunkStart = DateTime(chunkEnd.year, chunkEnd.month, chunkEnd.day).add(const Duration(days: 1));
    }

    return events;
  }

  CalendarImportEvent? _mapEvent(
    Event event, {
    required String calendarName,
    required String color,
    required Set<String> importedIds,
  }) {
    final eventId = event.eventId;
    final calendarId = event.calendarId;
    final start = event.start;
    if (eventId == null || calendarId == null || start == null) return null;

    final title = (event.title ?? '').trim();
    if (title.isEmpty) return null;

    final dedupId = '$calendarId:$eventId';
    if (importedIds.contains(dedupId)) return null;

    final localStart = start.toLocal();
    final scheduledAt = event.allDay == true
        ? DateTime(localStart.year, localStart.month, localStart.day, 9)
        : localStart;

    final durationMinutes = _durationMinutes(event, scheduledAt);

    return CalendarImportEvent(
      id: dedupId,
      title: title,
      description: event.description?.trim().isEmpty == true ? null : event.description?.trim(),
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      calendarName: calendarName,
      color: color,
      allDay: event.allDay == true,
    );
  }

  int _durationMinutes(Event event, DateTime scheduledAt) {
    final end = event.end?.toLocal();
    if (end == null) return 30;

    final minutes = end.difference(scheduledAt).inMinutes;
    if (minutes <= 0) return event.allDay == true ? 60 : 30;
    return minutes < 15 ? 15 : minutes;
  }

  (DateTime, DateTime) _rangeDates(CalendarImportRange range, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      CalendarImportRange.today => (
          today,
          DateTime(today.year, today.month, today.day, 23, 59, 59),
        ),
      CalendarImportRange.thisWeek => (
          today.subtract(Duration(days: today.weekday - 1)),
          today
              .subtract(Duration(days: today.weekday - 1))
              .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)),
        ),
      CalendarImportRange.next7Days => (
          today,
          today.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)),
        ),
    };
  }
}

String colorForCalendarIndex(int index) => FlorienColors.taskColors[index % FlorienColors.taskColors.length];
