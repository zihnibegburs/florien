import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/providers.dart';

Future<void> showStartFocusSheet(BuildContext context, WidgetRef ref) {
  return showFlorienBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _StartFocusSheet(),
  );
}

class _StartFocusSheet extends ConsumerStatefulWidget {
  const _StartFocusSheet();

  @override
  ConsumerState<_StartFocusSheet> createState() => _StartFocusSheetState();
}

class _StartFocusSheetState extends ConsumerState<_StartFocusSheet> {
  final _titleController = TextEditingController();
  int _duration = 25;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final s = ref.read(stringsProvider);
    final title = _titleController.text.trim().isEmpty
        ? s.freeFocusTitle
        : _titleController.text.trim();

    try {
      await ref.read(focusSessionProvider.notifier).startStandalone(
            title: title,
            durationMinutes: _duration,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorPrefix('$e')),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.startFocus,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: s.focusWhatHint),
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 20),
            Text(s.duration, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [15, 25, 30, 45, 60].map((min) {
                final selected = _duration == min;
                return ChoiceChip(
                  label: Text(s.minutesShort(min)),
                  selected: selected,
                  onSelected: (_) => setState(() => _duration = min),
                  selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _start,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(s.startFocus),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
