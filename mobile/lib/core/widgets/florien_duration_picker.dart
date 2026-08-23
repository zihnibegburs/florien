import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';

const florienDurationPresets = [5, 10, 15, 30, 45, 60, 90, 120];

String florienDurationLabel(int minutes) => switch (minutes) {
  60 => '1 saat',
  90 => '1,5 saat',
  120 => '2 saat',
  _ => '$minutes dk',
};

Future<int?> showFlorienDurationPicker({
  required BuildContext context,
  required int selected,
}) {
  return showFlorienSoftDialog<int>(
    context: context,
    maxWidth: 328,
    builder: (context) => FlorienDurationPicker(selected: selected),
  );
}

class FlorienDurationPicker extends StatelessWidget {
  const FlorienDurationPicker({super.key, required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FlorienSoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Süre', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Görevin ne kadar süreceğini seç',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < florienDurationPresets.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DurationChoice(
                    minutes: florienDurationPresets[i],
                    selected: florienDurationPresets[i] == selected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DurationChoice(
                    minutes: florienDurationPresets[i + 1],
                    selected: florienDurationPresets[i + 1] == selected,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({required this.minutes, required this.selected});

  final int minutes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected
        ? FlorienColors.onPrimary
        : palette.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, minutes),
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? FlorienColors.primary : palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.sm),
            border: Border.all(
              color: palette.border,
              width: selected ? 1.6 : FlorienBorders.thin,
            ),
          ),
          child: Center(
            child: Text(
              florienDurationLabel(minutes),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
