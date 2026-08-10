import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/calendar_import_service.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/timeline/home_tab.dart';

final calendarImportServiceProvider = Provider<CalendarImportService>((ref) => CalendarImportService());

class CalendarImportScreen extends ConsumerStatefulWidget {
  const CalendarImportScreen({super.key});

  @override
  ConsumerState<CalendarImportScreen> createState() => _CalendarImportScreenState();
}

class _CalendarImportScreenState extends ConsumerState<CalendarImportScreen> {
  bool _loading = true;
  bool _loadingEvents = false;
  bool _importing = false;
  String? _error;

  List<Calendar> _calendars = [];
  final Set<String> _selectedCalendarIds = {};
  CalendarImportRange _range = CalendarImportRange.today;
  List<CalendarImportEvent> _events = [];
  final Set<String> _selectedEventIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final service = ref.read(calendarImportServiceProvider);
    if (!service.isSupported) {
      setState(() {
        _loading = false;
        _error = 'unsupported';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final granted = await service.ensurePermissions();
      if (!granted) {
        setState(() {
          _loading = false;
          _error = 'permission';
        });
        return;
      }

      final calendars = await service.retrieveCalendars();
      final selected = calendars
          .where((calendar) => calendar.id != null)
          .map((calendar) => calendar.id!)
          .toSet();

      setState(() {
        _calendars = calendars;
        _selectedCalendarIds
          ..clear()
          ..addAll(selected);
        _loading = false;
      });

      if (selected.isNotEmpty) {
        await _loadEvents();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadEvents() async {
    if (_selectedCalendarIds.isEmpty) {
      setState(() {
        _events = [];
        _selectedEventIds.clear();
      });
      return;
    }

    setState(() {
      _loadingEvents = true;
      _error = null;
    });

    try {
      final service = ref.read(calendarImportServiceProvider);
      final importedIds = await ref.read(settingsStorageProvider).getImportedCalendarEventIds();
      final calendarsById = {
        for (final calendar in _calendars)
          if (calendar.id != null) calendar.id!: calendar,
      };
      final events = await service.retrieveEvents(
        calendarsById: calendarsById,
        calendarIds: _selectedCalendarIds.toList(),
        range: _range,
        importedIds: importedIds,
      );

      if (!mounted) return;
      setState(() {
        _events = events;
        _selectedEventIds
          ..clear()
          ..addAll(events.map((event) => event.id));
        _loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        _error = '$e';
      });
    }
  }

  Future<void> _importSelected() async {
    final selectedEvents = _events.where((event) => _selectedEventIds.contains(event.id)).toList();
    if (selectedEvents.isEmpty) return;

    setState(() => _importing = true);

    try {
      final count = await ref.read(timelineProvider.notifier).importCalendarEvents(selectedEvents);
      if (!mounted) return;

      final s = ref.read(stringsProvider);
      ref.read(homeTabProvider.notifier).state = HomeTab.today;
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.calendarImportSuccess(count))),
      );
    } catch (e) {
      if (!mounted) return;
      final s = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.friendlyTaskActionError(e)),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final locale = dateLocaleFor(lang);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(s.calendarImportTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, s, locale),
      bottomNavigationBar: _events.isEmpty || _importing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: _selectedEventIds.isEmpty ? null : _importSelected,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(s.calendarImportButton(_selectedEventIds.length)),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context, S s, String locale) {
    if (_error == 'unsupported') {
      return _MessageView(
        icon: Icons.devices_other_rounded,
        title: s.calendarImportUnavailable,
      );
    }

    if (_error == 'permission') {
      return _MessageView(
        icon: Icons.lock_outline_rounded,
        title: s.calendarImportPermissionDenied,
        actionLabel: s.retry,
        onAction: _initialize,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Text(
          s.calendarImportSubtitle,
          style: TextStyle(color: context.palette.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        Text(s.calendarImportSelectCalendars, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_calendars.isEmpty)
          _EmptyCard(message: s.calendarImportNoCalendars)
        else
          ..._calendars.map((calendar) {
            final id = calendar.id;
            if (id == null) return const SizedBox.shrink();
            final selected = _selectedCalendarIds.contains(id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: selected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedCalendarIds.add(id);
                    } else {
                      _selectedCalendarIds.remove(id);
                    }
                  });
                  _loadEvents();
                },
                title: Text(calendar.name ?? calendar.accountName ?? id),
                subtitle: calendar.accountName != null ? Text(calendar.accountName!) : null,
                secondary: const Icon(Icons.calendar_month_rounded, color: FlorienColors.primary),
              ),
            );
          }),
        const SizedBox(height: 16),
        Text(s.calendarImportDateRange, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RangeChip(
              label: s.calendarImportToday,
              selected: _range == CalendarImportRange.today,
              onTap: () => _setRange(CalendarImportRange.today),
            ),
            _RangeChip(
              label: s.calendarImportThisWeek,
              selected: _range == CalendarImportRange.thisWeek,
              onTap: () => _setRange(CalendarImportRange.thisWeek),
            ),
            _RangeChip(
              label: s.calendarImportNext7Days,
              selected: _range == CalendarImportRange.next7Days,
              onTap: () => _setRange(CalendarImportRange.next7Days),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(s.calendarImportPreview, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (_events.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedEventIds.length == _events.length) {
                      _selectedEventIds.clear();
                    } else {
                      _selectedEventIds.addAll(_events.map((event) => event.id));
                    }
                  });
                },
                child: Text(
                  _selectedEventIds.length == _events.length
                      ? s.calendarImportDeselectAll
                      : s.calendarImportSelectAll,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingEvents)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_events.isEmpty)
          _EmptyCard(message: s.calendarImportNoEvents)
        else
          ..._events.map((event) {
            final selected = _selectedEventIds.contains(event.id);
            final timeLabel = event.allDay
                ? s.calendarImportAllDay
                : DateFormat('d MMM, HH:mm', locale).format(event.scheduledAt);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: selected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEventIds.add(event.id);
                    } else {
                      _selectedEventIds.remove(event.id);
                    }
                  });
                },
                title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '$timeLabel · ${s.minutesShort(event.durationMinutes)} · ${event.calendarName}',
                ),
                secondary: Container(
                  width: 10,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FlorienColors.fromHex(event.color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        if (_error != null && _error != 'unsupported' && _error != 'permission') ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
        ],
      ],
    );
  }

  void _setRange(CalendarImportRange range) {
    setState(() => _range = range);
    _loadEvents();
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: FlorienColors.primary.withValues(alpha: 0.15),
      checkmarkColor: FlorienColors.primary,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.textSecondary),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: context.palette.textSecondary),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
