import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/core/theme/florien_theme.dart';

class RecurrencePicker extends ConsumerWidget {
  const RecurrencePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RecurrenceSelection value;
  final ValueChanged<RecurrenceSelection> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.repeat, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showOptions(context, s),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, color: FlorienColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.recurrenceLabel(value),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.palette.textSecondary),
              ],
            ),
          ),
        ),
        if (value.type == RecurrenceType.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(s.repeatEvery, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _IntervalStepper(
                value: value.interval,
                onChanged: (interval) => onChanged(value.copyWith(interval: interval)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: RecurrenceUnit.values.map((unit) {
                    final selected = value.unit == unit;
                    return ChoiceChip(
                      label: Text(s.recurrenceUnitLabel(unit)),
                      selected: selected,
                      onSelected: (_) => onChanged(value.copyWith(unit: unit)),
                      selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _showOptions(BuildContext context, S s) async {
    final selected = await showFlorienBottomSheet<RecurrenceType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.repeat,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...RecurrenceType.values.map(
              (type) => ListTile(
                leading: Icon(
                  _iconFor(type),
                  color: value.type == type ? FlorienColors.primary : context.palette.textSecondary,
                ),
                title: Text(
                  s.recurrenceTypeLabel(type),
                  style: TextStyle(
                    fontWeight: value.type == type ? FontWeight.w700 : FontWeight.w500,
                    color: value.type == type ? FlorienColors.primary : null,
                  ),
                ),
                trailing: value.type == type
                    ? const Icon(Icons.check_rounded, color: FlorienColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, type),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null) {
      onChanged(value.copyWith(type: selected));
    }
  }

  IconData _iconFor(RecurrenceType type) => switch (type) {
        RecurrenceType.none => Icons.block_rounded,
        RecurrenceType.daily => Icons.today_rounded,
        RecurrenceType.weekly => Icons.date_range_rounded,
        RecurrenceType.monthly => Icons.calendar_month_rounded,
        RecurrenceType.yearly => Icons.event_rounded,
        RecurrenceType.custom => Icons.tune_rounded,
      };
}

class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < 30 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
