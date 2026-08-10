import 'dart:async';

import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/core/theme/florien_theme.dart';

Future<void> showRewardTimerSheet(BuildContext context, S s, {required String reward, required int minutes}) {
  return showFlorienBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RewardTimerSheet(reward: reward, minutes: minutes, s: s),
  );
}

class _RewardTimerSheet extends StatefulWidget {
  const _RewardTimerSheet({required this.reward, required this.minutes, required this.s});

  final String reward;
  final int minutes;
  final S s;

  @override
  State<_RewardTimerSheet> createState() => _RewardTimerSheetState();
}

class _RewardTimerSheetState extends State<_RewardTimerSheet> {
  late int _remaining;
  Timer? _timer;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _remaining = widget.minutes * 60;
    _timer?.cancel();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() => _remaining--);
    });
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
          const Icon(Icons.card_giftcard_rounded, size: 48, color: Color(0xFFE6A800)),
          const SizedBox(height: 16),
          Text(widget.s.rewardTimerActive, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(widget.reward, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          if (_running) ...[
            const SizedBox(height: 20),
            Text(_formatted, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: FlorienColors.primary)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _running ? null : _start,
              child: Text(_running ? _formatted : widget.s.startRewardTimer),
            ),
          ),
        ],
      ),
    );
  }
}
