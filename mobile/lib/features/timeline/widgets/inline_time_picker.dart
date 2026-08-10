import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/theme/florien_theme.dart';

class InlineTimePicker extends ConsumerStatefulWidget {
  const InlineTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.minuteStep = 5,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  final int minuteStep;

  @override
  ConsumerState<InlineTimePicker> createState() => _InlineTimePickerState();
}

class _InlineTimePickerState extends ConsumerState<InlineTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  List<int> get _minuteOptions {
    final step = widget.minuteStep;
    return List.generate(60 ~/ step, (i) => i * step);
  }

  int _nearestMinuteIndex(int minute) {
    final options = _minuteOptions;
    var best = 0;
    var bestDiff = 999;
    for (var i = 0; i < options.length; i++) {
      final diff = (options[i] - minute).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: widget.value.hour);
    _minuteController = FixedExtentScrollController(
      initialItem: _nearestMinuteIndex(widget.value.minute),
    );
  }

  @override
  void didUpdateWidget(covariant InlineTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (_hourController.hasClients && _hourController.selectedItem != widget.value.hour) {
        _hourController.jumpToItem(widget.value.hour);
      }
      final minuteIndex = _nearestMinuteIndex(widget.value.minute);
      if (_minuteController.hasClients && _minuteController.selectedItem != minuteIndex) {
        _minuteController.jumpToItem(minuteIndex);
      }
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _emit(int hourIndex, int minuteIndex) {
    final hour = hourIndex.clamp(0, 23);
    final minute = _minuteOptions[minuteIndex.clamp(0, _minuteOptions.length - 1)];
    widget.onChanged(TimeOfDay(hour: hour, minute: minute));
  }

  List<TimeOfDay> _quickSlots() {
    final now = TimeOfDay.now();
    var total = now.hour * 60 + now.minute;
    total = ((total + widget.minuteStep - 1) ~/ widget.minuteStep) * widget.minuteStep;

    final slots = <TimeOfDay>[];
    for (var i = 0; i < 4; i++) {
      slots.add(TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60));
      total += 15;
    }
    return slots;
  }

  String _formatChip(BuildContext context, TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final quickSlots = _quickSlots();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: FlorienColors.primary),
                const SizedBox(width: 12),
                Text(
                  widget.value.format(context),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(s.nowLabel),
                  onPressed: () {
                    final rounded = quickSlots.first;
                    widget.onChanged(rounded);
                  },
                  backgroundColor: FlorienColors.primary.withValues(alpha: 0.12),
                  side: BorderSide.none,
                ),
                ...quickSlots.map((slot) {
                  final selected = widget.value.hour == slot.hour && widget.value.minute == slot.minute;
                  return ActionChip(
                    label: Text(_formatChip(context, slot)),
                    onPressed: () => widget.onChanged(slot),
                    backgroundColor: selected
                        ? FlorienColors.primary.withValues(alpha: 0.2)
                        : context.palette.background,
                    side: BorderSide(
                      color: selected ? FlorienColors.primary : context.palette.border,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _hourController,
                    itemExtent: 40,
                    magnification: 1.1,
                    squeeze: 1.1,
                    useMagnifier: true,
                    onSelectedItemChanged: (index) => _emit(index, _minuteController.selectedItem),
                    children: List.generate(
                      24,
                      (i) => Center(
                        child: Text(
                          i.toString().padLeft(2, '0'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  ':',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.palette.textSecondary),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _minuteController,
                    itemExtent: 40,
                    magnification: 1.1,
                    squeeze: 1.1,
                    useMagnifier: true,
                    onSelectedItemChanged: (index) => _emit(_hourController.selectedItem, index),
                    children: _minuteOptions
                        .map(
                          (m) => Center(
                            child: Text(
                              m.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
