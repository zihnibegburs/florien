import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Full-screen ringing UI for a plan alarm. Loops until the user dismisses.
class PlanAlarmRingOverlay extends ConsumerStatefulWidget {
  const PlanAlarmRingOverlay({super.key, required this.request});

  final PlanAlarmRingRequest request;

  @override
  ConsumerState<PlanAlarmRingOverlay> createState() =>
      _PlanAlarmRingOverlayState();
}

class _PlanAlarmRingOverlayState extends ConsumerState<PlanAlarmRingOverlay> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _hapticPulse;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    unawaited(_startRinging());
  }

  @override
  void dispose() {
    _hapticPulse?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startRinging() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.alarm,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
      await _player.setAsset(TaskAlarmService.planAlarmAssetPath);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(1);
      await _player.play();
      unawaited(HapticFeedback.heavyImpact());
      _hapticPulse = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(HapticFeedback.mediumImpact());
      });
    } catch (error) {
      debugPrint('Plan alarm ring failed: $error');
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  Future<void> _dismiss() async {
    if (_stopping) return;
    _stopping = true;
    _hapticPulse?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    ref.read(planAlarmRingProvider.notifier).state = null;
    unawaited(
      ref.read(taskAlarmServiceProvider).cancelPlanAlarm(widget.request.taskId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.textPrimary.withValues(alpha: 0.94),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.alarm_on_rounded, size: 88, color: palette.surface),
              const SizedBox(height: 20),
              Text(
                context.l10n('Alarm'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: palette.surface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.request.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.surface.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _dismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.surface,
                    foregroundColor: palette.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(context.l10n('Kapat')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
