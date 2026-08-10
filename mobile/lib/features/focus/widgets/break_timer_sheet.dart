import 'dart:async';

import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/core/theme/florien_theme.dart';

Future<void> showBreakTimerSheet(BuildContext context, S s, {required int minutes, VoidCallback? onDone}) {
  return showFlorienBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => _BreakTimerSheet(minutes: minutes, s: s, onDone: onDone),
  );
}

class _BreakTimerSheet extends StatefulWidget {
  const _BreakTimerSheet({required this.minutes, required this.s, this.onDone});

  final int minutes;
  final S s;
  final VoidCallback? onDone;

  @override
  State<_BreakTimerSheet> createState() => _BreakTimerSheetState();
}

class _BreakTimerSheetState extends State<_BreakTimerSheet> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.minutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        widget.onDone?.call();
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    final m = _remaining ~/ 60;
    final sec = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement_rounded, size: 48, color: FlorienColors.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(widget.s.breakTime, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(widget.s.breakHint, textAlign: TextAlign.center, style: TextStyle(color: context.palette.textSecondary)),
          const SizedBox(height: 24),
          Text(_formatted, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: FlorienColors.primary)),
          const SizedBox(height: 24),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.s.skipBreak)),
        ],
      ),
    );
  }
}
