import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';
import 'package:florien/features/providers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusTimerTab extends StatefulWidget {
  const FocusTimerTab({
    super.key,
    this.launchRequest,
    this.resetSignal = 0,
    this.onStandaloneFocusStarted,
    this.onTaskProgressChanged,
    this.onTaskCompleted,
    this.onSessionClosed,
    this.onFocusAlarmScheduled,
    this.onFocusAlarmCompleted,
    this.onFocusAlarmCancelled,
    this.alarmAvailable = true,
    this.onPremiumAlarmPressed,
  });

  final FocusTaskLaunch? launchRequest;
  final int resetSignal;
  final Future<FocusTaskLaunch> Function(int durationMinutes)?
  onStandaloneFocusStarted;
  final ValueChanged<ActiveFocusTask?>? onTaskProgressChanged;
  final Future<void> Function(String taskId)? onTaskCompleted;
  final VoidCallback? onSessionClosed;
  final Future<void> Function(DateTime alarmAt, String title)?
  onFocusAlarmScheduled;
  final Future<void> Function(String title)? onFocusAlarmCompleted;
  final Future<void> Function()? onFocusAlarmCancelled;
  final bool alarmAvailable;
  final VoidCallback? onPremiumAlarmPressed;

  @override
  State<FocusTimerTab> createState() => _FocusTimerTabState();
}

class _FocusTimerTabState extends State<FocusTimerTab>
    with SingleTickerProviderStateMixin {
  static const _selectedMusicPreferenceKey = 'focus_timer_selected_music';
  static const _musicAutoPlayPreferenceKey = 'focus_timer_music_auto_play';

  int _selectedMinutes = 5;
  int _remainingSeconds = 5 * 60;
  int _sessionTotalSeconds = 5 * 60;
  DateTime? _sessionStartedAt;
  DateTime? _plannedEndAt;
  Timer? _timer;
  bool _alarmEnabled = false;
  double _setupLastAngle = 0;
  double _setupDragProgress = 0;
  String? _taskId;
  String? _taskTitle;
  String _taskIcon = TaskIcons.defaultName;
  String _taskColor = '#6C5CE7';
  bool _taskCompletionRequested = false;
  Future<void>? _taskCompletionFuture;
  bool _automaticTask = false;
  bool _creatingStandaloneTask = false;
  bool _isFinishing = false;
  bool _focusAlarmScheduled = false;
  late final AudioPlayer _focusMusicPlayer;
  _FocusMusicTrack? _selectedMusic;
  String? _loadedMusicId;
  bool _musicAutoPlay = false;
  bool _musicActiveForSession = false;
  late final AnimationController _completionController;
  late final Animation<double> _completionScale;
  late final Animation<double> _completionCelebrationOpacity;

  @override
  void initState() {
    super.initState();
    _alarmEnabled = widget.alarmAvailable;
    _focusMusicPlayer = AudioPlayer();
    unawaited(_focusMusicPlayer.setLoopMode(LoopMode.one));
    unawaited(_focusMusicPlayer.setVolume(.58));
    unawaited(_restoreMusicSettings());
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _completionScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.04,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.04,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_completionController);
    _completionCelebrationOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 58),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_completionController);
    final request = widget.launchRequest;
    if (request != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startTaskFocus(request),
      );
    }
  }

  @override
  void didUpdateWidget(covariant FocusTimerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarmAvailable && !widget.alarmAvailable && _alarmEnabled) {
      _alarmEnabled = false;
      unawaited(_cancelFocusAlarm());
    }
    if (widget.resetSignal != oldWidget.resetSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closeSession();
      });
      return;
    }
    final request = widget.launchRequest;
    if (request != null &&
        request.taskId != _taskId &&
        !_sameLaunch(request, oldWidget.launchRequest)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startTaskFocus(request),
      );
    } else if (request == null && oldWidget.launchRequest?.automatic == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closeSession();
      });
    }
  }

  bool get _isRunning => _timer?.isActive ?? false;
  bool get _sessionActive => _sessionStartedAt != null;

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_cancelFocusAlarm());
    unawaited(_focusMusicPlayer.dispose());
    _completionController.dispose();
    super.dispose();
  }

  Future<void> _restoreMusicSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final selectedId = preferences.getString(_selectedMusicPreferenceKey);
    final selectedMusic = _focusMusicTracks
        .where((track) => track.id == selectedId)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _selectedMusic = selectedMusic;
      _musicAutoPlay =
          preferences.getBool(_musicAutoPlayPreferenceKey) ?? false;
    });
  }

  Future<void> _persistMusicSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final selectedId = _selectedMusic?.id;
    if (selectedId == null) {
      await preferences.remove(_selectedMusicPreferenceKey);
    } else {
      await preferences.setString(_selectedMusicPreferenceKey, selectedId);
    }
    await preferences.setBool(_musicAutoPlayPreferenceKey, _musicAutoPlay);
  }

  Future<void> _prepareSelectedMusic() async {
    final selectedMusic = _selectedMusic;
    if (selectedMusic == null || _loadedMusicId == selectedMusic.id) return;
    await _focusMusicPlayer.setAsset(selectedMusic.assetPath);
    await _focusMusicPlayer.setLoopMode(LoopMode.one);
    _loadedMusicId = selectedMusic.id;
  }

  Future<void> _playSelectedMusic({bool showError = false}) async {
    if (_selectedMusic == null) return;
    try {
      final audioSession = await AudioSession.instance;
      await audioSession.configure(AudioSessionConfiguration.music());
      await _prepareSelectedMusic();
      unawaited(_focusMusicPlayer.play());
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Focus music could not be played: $error');
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müzik şu anda oynatılamadı.')),
        );
      }
    }
  }

  Future<void> _pauseFocusMusic() async {
    try {
      await _focusMusicPlayer.pause();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Focus music could not be paused: $error');
    }
  }

  Future<void> _stopFocusMusic() async {
    try {
      await _focusMusicPlayer.pause();
      await _focusMusicPlayer.seek(Duration.zero);
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Focus music could not be stopped: $error');
    }
  }

  Future<void> _handleMusicMenuSelection(String value) async {
    if (value == _FocusMusicMenuValue.none) {
      setState(() {
        _selectedMusic = null;
        _loadedMusicId = null;
        _musicActiveForSession = false;
      });
      await _stopFocusMusic();
      await _persistMusicSettings();
      return;
    }

    if (value == _FocusMusicMenuValue.autoPlayOn ||
        value == _FocusMusicMenuValue.autoPlayOff) {
      final autoPlay = value == _FocusMusicMenuValue.autoPlayOn;
      setState(() => _musicAutoPlay = autoPlay);
      if (autoPlay && _isRunning && _selectedMusic != null) {
        _musicActiveForSession = true;
        await _playSelectedMusic(showError: true);
      } else if (!autoPlay && _musicActiveForSession) {
        _musicActiveForSession = false;
        await _pauseFocusMusic();
      }
      await _persistMusicSettings();
      return;
    }

    final selectedMusic = _focusMusicTracks
        .where((track) => value == _FocusMusicMenuValue.track(track.id))
        .firstOrNull;
    if (selectedMusic == null) return;

    setState(() {
      _selectedMusic = selectedMusic;
      _loadedMusicId = null;
      if (_sessionActive) _musicActiveForSession = true;
    });
    await _persistMusicSettings();
    if (_isRunning) {
      await _playSelectedMusic(showError: true);
    }
  }

  Future<void> _toggleTimer() async {
    if (_isRunning) {
      _timer?.cancel();
      unawaited(_cancelFocusAlarm());
      if (_musicActiveForSession) unawaited(_pauseFocusMusic());
      setState(() {});
      _publishTaskProgress();
      return;
    }
    if (_remainingSeconds <= 0) return;

    if (!_sessionActive &&
        _taskId == null &&
        widget.onStandaloneFocusStarted != null) {
      if (_creatingStandaloneTask) return;
      setState(() => _creatingStandaloneTask = true);
      try {
        final launch = await widget.onStandaloneFocusStarted!(_selectedMinutes);
        if (!mounted) return;
        setState(() {
          _selectedMinutes = launch.durationMinutes.clamp(1, 24 * 60);
          _remainingSeconds = _selectedMinutes * 60;
          _sessionTotalSeconds = _remainingSeconds;
          _taskId = launch.taskId;
          _taskTitle = launch.title;
          _taskIcon = launch.icon;
          _taskColor = launch.color;
          _taskCompletionRequested = false;
          _automaticTask = false;
        });
      } catch (error) {
        debugPrint('Standalone focus task could not be persisted: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Odak görevi kaydedilemedi. Tekrar deneyin.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _creatingStandaloneTask = false);
      }
    }

    final startingNewSession = !_sessionActive;
    final now = DateTime.now();
    _sessionStartedAt ??= now;
    _sessionTotalSeconds = _sessionActive
        ? math.max(_sessionTotalSeconds, _remainingSeconds)
        : _remainingSeconds;
    _plannedEndAt = now.add(Duration(seconds: _remainingSeconds));
    if (startingNewSession) {
      _musicActiveForSession = _musicAutoPlay && _selectedMusic != null;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _musicActiveForSession = false;
        unawaited(_stopFocusMusic());
        setState(() => _remainingSeconds = 0);
        _publishTaskProgress();
        final taskId = _taskId;
        if (taskId != null && !_automaticTask) {
          unawaited(_completeTaskAfterTimer(taskId));
        }
        if (_alarmEnabled) {
          unawaited(_completeFocusAlarm());
          unawaited(SystemSound.play(SystemSoundType.alert));
          unawaited(HapticFeedback.heavyImpact());
        }
      } else {
        setState(() => _remainingSeconds--);
        _publishTaskProgress();
      }
    });
    setState(() {});
    _publishTaskProgress();
    unawaited(_scheduleFocusAlarm());
    if (_musicActiveForSession) unawaited(_playSelectedMusic());
  }

  void _closeSession() {
    _timer?.cancel();
    unawaited(_cancelFocusAlarm());
    _musicActiveForSession = false;
    unawaited(_stopFocusMusic());
    setState(() {
      _sessionStartedAt = null;
      _plannedEndAt = null;
      _sessionTotalSeconds = _selectedMinutes * 60;
      _remainingSeconds = _selectedMinutes * 60;
      _taskId = null;
      _taskTitle = null;
      _taskIcon = TaskIcons.defaultName;
      _taskColor = '#6C5CE7';
      _taskCompletionRequested = false;
      _taskCompletionFuture = null;
      _automaticTask = false;
      _isFinishing = false;
    });
    widget.onTaskProgressChanged?.call(null);
    widget.onSessionClosed?.call();
  }

  void _startTaskFocus(FocusTaskLaunch request) {
    if (!mounted) return;
    _timer?.cancel();
    unawaited(_cancelFocusAlarm());
    _musicActiveForSession = _musicAutoPlay && _selectedMusic != null;
    final duration = request.durationMinutes.clamp(1, 24 * 60);
    final now = DateTime.now();
    final scheduledEnd = request.endsAt;
    final scheduledStart = request.startedAt;
    final automaticRemaining = scheduledEnd?.difference(now).inSeconds;
    if (request.automatic &&
        (scheduledStart == null ||
            scheduledEnd == null ||
            automaticRemaining == null ||
            automaticRemaining <= 0)) {
      _closeSession();
      return;
    }
    setState(() {
      _selectedMinutes = duration;
      _remainingSeconds = request.automatic
          ? automaticRemaining!
          : duration * 60;
      _sessionTotalSeconds = request.automatic
          ? scheduledEnd!.difference(scheduledStart!).inSeconds
          : _remainingSeconds;
      _sessionStartedAt = request.automatic ? scheduledStart : null;
      _plannedEndAt = request.automatic ? scheduledEnd : null;
      _taskId = request.taskId;
      _taskTitle = request.title;
      _taskIcon = request.icon;
      _taskColor = request.color;
      _taskCompletionRequested = false;
      _taskCompletionFuture = null;
      _automaticTask = request.automatic;
    });
    unawaited(_toggleTimer());
  }

  bool _sameLaunch(FocusTaskLaunch? a, FocusTaskLaunch? b) =>
      a?.taskId == b?.taskId &&
      a?.title == b?.title &&
      a?.durationMinutes == b?.durationMinutes &&
      a?.icon == b?.icon &&
      a?.color == b?.color &&
      a?.startedAt == b?.startedAt &&
      a?.endsAt == b?.endsAt &&
      a?.automatic == b?.automatic;

  void _addMinute() {
    final elapsedSeconds = math.max(
      0,
      _sessionTotalSeconds - _remainingSeconds,
    );
    setState(() {
      _sessionTotalSeconds += 60;
      _remainingSeconds = _sessionTotalSeconds - elapsedSeconds;
      _plannedEndAt = (_plannedEndAt ?? DateTime.now()).add(
        const Duration(minutes: 1),
      );
    });
    _publishTaskProgress();
    unawaited(_scheduleFocusAlarm());
  }

  void _removeMinute() {
    final elapsedSeconds = math.max(
      0,
      _sessionTotalSeconds - _remainingSeconds,
    );
    final reducedTotalSeconds = math.max(0, _sessionTotalSeconds - 60);
    if (reducedTotalSeconds <= elapsedSeconds) {
      setState(() {
        _sessionTotalSeconds = math.max(1, elapsedSeconds);
        _remainingSeconds = 0;
        _plannedEndAt = DateTime.now();
      });
      _publishTaskProgress();
      unawaited(_completeAndCloseSession());
      return;
    }

    setState(() {
      _sessionTotalSeconds = reducedTotalSeconds;
      _remainingSeconds = reducedTotalSeconds - elapsedSeconds;
      _plannedEndAt = (_plannedEndAt ?? DateTime.now()).subtract(
        const Duration(minutes: 1),
      );
    });
    _publishTaskProgress();
    unawaited(_scheduleFocusAlarm());
  }

  void _toggleAlarm() {
    if (!widget.alarmAvailable) {
      widget.onPremiumAlarmPressed?.call();
      return;
    }
    setState(() => _alarmEnabled = !_alarmEnabled);
    if (_alarmEnabled) {
      unawaited(_scheduleFocusAlarm());
    } else {
      unawaited(_cancelFocusAlarm());
    }
  }

  Future<void> _scheduleFocusAlarm() async {
    final schedule = widget.onFocusAlarmScheduled;
    final alarmAt = _plannedEndAt;
    if (!_alarmEnabled || !_isRunning || schedule == null || alarmAt == null) {
      return;
    }
    try {
      await schedule(alarmAt, _taskTitle ?? 'Odaklanma tamamlandı');
      _focusAlarmScheduled = true;
    } catch (error) {
      debugPrint('Focus alarm could not be scheduled: $error');
    }
  }

  Future<void> _completeFocusAlarm() async {
    final complete = widget.onFocusAlarmCompleted;
    if (complete == null) return;
    try {
      await complete(_taskTitle ?? 'Odaklanma tamamlandı');
      _focusAlarmScheduled = false;
    } catch (error) {
      debugPrint('Focus alarm could not be completed: $error');
    }
  }

  Future<void> _cancelFocusAlarm() async {
    final cancel = widget.onFocusAlarmCancelled;
    if (cancel == null || !_focusAlarmScheduled) return;
    _focusAlarmScheduled = false;
    try {
      await cancel();
    } catch (error) {
      debugPrint('Focus alarm could not be cancelled: $error');
    }
  }

  void _publishTaskProgress() {
    final taskId = _taskId;
    if (taskId == null) {
      widget.onTaskProgressChanged?.call(null);
      return;
    }
    widget.onTaskProgressChanged?.call(
      ActiveFocusTask(
        taskId: taskId,
        totalSeconds: _sessionTotalSeconds,
        remainingSeconds: _remainingSeconds,
        isRunning: _isRunning,
      ),
    );
  }

  Future<void> _markTaskCompleted(String taskId) async {
    final existing = _taskCompletionFuture;
    if (existing != null) return existing;
    final complete = widget.onTaskCompleted;
    if (_taskCompletionRequested || complete == null) return;
    _taskCompletionRequested = true;
    final future = _runTaskCompletion(taskId, complete);
    _taskCompletionFuture = future;
    return future;
  }

  Future<void> _runTaskCompletion(
    String taskId,
    Future<void> Function(String taskId) complete,
  ) async {
    try {
      await complete(taskId);
      if (mounted && _taskId == taskId) {
        widget.onTaskProgressChanged?.call(null);
      }
    } catch (error) {
      _taskCompletionRequested = false;
      _taskCompletionFuture = null;
      rethrow;
    }
  }

  Future<void> _completeTaskAfterTimer(String taskId) async {
    try {
      await _markTaskCompleted(taskId);
    } catch (error) {
      debugPrint('Focus task could not be completed: $error');
    }
  }

  Future<void> _completeAndCloseSession() async {
    final taskId = _taskId;
    _timer?.cancel();
    unawaited(_cancelFocusAlarm());
    _musicActiveForSession = false;
    unawaited(_stopFocusMusic());
    if (taskId != null) {
      setState(() => _remainingSeconds = 0);
      _publishTaskProgress();
      await _markTaskCompleted(taskId);
    }
    if (mounted) await _finishSessionWithAnimation();
  }

  Future<void> _finishSessionWithAnimation() async {
    if (_isFinishing) return;
    _musicActiveForSession = false;
    unawaited(_stopFocusMusic());
    setState(() => _isFinishing = true);
    unawaited(HapticFeedback.mediumImpact());

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _closeSession();
      return;
    }

    await _completionController.forward(from: 0);
    if (mounted) _closeSession();
  }

  void _setDuration(int minutes) {
    setState(() {
      _selectedMinutes = minutes.clamp(1, 24 * 60);
      _remainingSeconds = _selectedMinutes * 60;
      _sessionTotalSeconds = _remainingSeconds;
    });
  }

  Future<void> _selectDuration(int minutes) async {
    if (minutes > 0) {
      _setDuration(minutes);
      await _toggleTimer();
      return;
    }
    final customMinutes = await _showCustomDurationPicker();
    if (customMinutes != null && mounted) {
      _setDuration(customMinutes);
      await _toggleTimer();
    }
  }

  Future<int?> _showCustomDurationPicker() {
    var hours = _selectedMinutes ~/ 60;
    var minutes = _selectedMinutes % 60;
    if (hours >= 24) {
      hours = 24;
      minutes = 0;
    }
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalMinutes = hours * 60 + minutes;
          final canSave = totalMinutes > 0 && totalMinutes <= 24 * 60;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Özel süre',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hours == 24
                        ? '24 saat'
                        : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const SizedBox(width: 58, child: Text('Saat')),
                      Expanded(
                        child: Slider(
                          value: hours.toDouble(),
                          min: 0,
                          max: 24,
                          divisions: 24,
                          label: '$hours saat',
                          onChanged: (value) => setModalState(() {
                            hours = value.round();
                            if (hours == 24) minutes = 0;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text('$hours', textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 58, child: Text('Dakika')),
                      Expanded(
                        child: Slider(
                          value: minutes.toDouble(),
                          min: 0,
                          max: 55,
                          divisions: 11,
                          label: '$minutes dk',
                          onChanged: hours == 24
                              ? null
                              : (value) => setModalState(
                                  () => minutes = value.round(),
                                ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text('$minutes', textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Vazgeç'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: canSave
                              ? () => Navigator.pop(context, totalMinutes)
                              : null,
                          child: const Text('Uygula'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _dialAngle(Offset position, Size size) {
    final center = size.center(Offset.zero);
    return math.atan2(position.dy - center.dy, position.dx - center.dx);
  }

  void _startDurationRotation(Offset position, Size size) {
    if (_sessionActive) return;
    _setupLastAngle = _dialAngle(position, size);
    _setupDragProgress = _selectedMinutes / 60;
  }

  void _updateDurationRotation(Offset position, Size size) {
    if (_sessionActive) return;
    final angle = _dialAngle(position, size);
    var delta = angle - _setupLastAngle;
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;
    _setupLastAngle = angle;
    _setupDragProgress = (_setupDragProgress + delta / (math.pi * 2)).clamp(
      1 / 60,
      1,
    );
    final minutes = (_setupDragProgress * 60).round().clamp(1, 60);
    if (minutes != _selectedMinutes) _setDuration(minutes);
  }

  String get _remainingLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _clockLabel(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final setupProgress = _selectedMinutes / 60;
    final elapsedProgress = _sessionTotalSeconds == 0
        ? 0.0
        : (_sessionTotalSeconds - _remainingSeconds) / _sessionTotalSeconds;

    return IgnorePointer(
      ignoring: _isFinishing,
      child: SafeArea(
        child: ListView(
          physics: _sessionActive
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _isFinishing
                  ? const SizedBox(
                      key: ValueKey('focus-top-controls-hidden'),
                      height: 44,
                    )
                  : Row(
                      key: const ValueKey('focus-top-controls'),
                      children: [
                        _FocusMusicMenuButton(
                          selectedMusic: _selectedMusic,
                          autoPlay: _musicAutoPlay,
                          isPlaying: _focusMusicPlayer.playing,
                          onSelected: (value) =>
                              unawaited(_handleMusicMenuSelection(value)),
                        ),
                        const SizedBox(width: 12),
                        if (_sessionActive)
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _AlarmToggleButton(
                                enabled: _alarmEnabled,
                                available: widget.alarmAvailable,
                                onTap: _toggleAlarm,
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _DurationMenuButton(
                                onSelected: _selectDuration,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _sessionActive
                  ? _ActiveTimer(
                      key: const ValueKey('active-timer'),
                      title: _taskTitle ?? 'Odaklan',
                      taskIcon: _taskTitle == null ? null : _taskIcon,
                      taskColor: _taskColor,
                      remainingLabel: _remainingLabel,
                      timeRange:
                          '${_clockLabel(_sessionStartedAt)} → ${_clockLabel(_plannedEndAt)}',
                      progress: elapsedProgress.clamp(.025, 1),
                      isRunning: _isRunning,
                      isFinished: _remainingSeconds <= 0,
                      onRemoveMinute: _removeMinute,
                      onAddMinute: _addMinute,
                      onToggle: () => unawaited(_toggleTimer()),
                      onFinish: () => unawaited(_completeAndCloseSession()),
                      onComplete: () => unawaited(_completeAndCloseSession()),
                      isCelebrating: _isFinishing,
                      celebrationScale: _completionScale,
                      celebrationOpacity: _completionCelebrationOpacity,
                    )
                  : _TimerSetup(
                      key: const ValueKey('timer-setup'),
                      selectedMinutes: _selectedMinutes,
                      progress: setupProgress.clamp(0, 1),
                      onRotationStart: _startDurationRotation,
                      onRotationUpdate: _updateDurationRotation,
                      onStart: () => unawaited(_toggleTimer()),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerSetup extends StatelessWidget {
  const _TimerSetup({
    super.key,
    required this.selectedMinutes,
    required this.progress,
    required this.onRotationStart,
    required this.onRotationUpdate,
    required this.onStart,
  });

  final int selectedMinutes;
  final double progress;
  final void Function(Offset, Size) onRotationStart;
  final void Function(Offset, Size) onRotationUpdate;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 96),
      const _FocusTitle(),
      const SizedBox(height: 40),
      _TimerDial(
        key: const ValueKey('setup-focus-dial'),
        progress: progress,
        showHandle: true,
        showDurationLabels: true,
        onRotationStart: onRotationStart,
        onRotationUpdate: onRotationUpdate,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedMinutes <= 60
                  ? '$selectedMinutes'
                  : '${selectedMinutes ~/ 60}:${(selectedMinutes % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: selectedMinutes <= 60 ? 58 : 46,
                fontWeight: FontWeight.w500,
                letterSpacing: -2,
              ),
            ),
            Text(
              selectedMinutes <= 60 ? 'DK.' : 'SA:DK',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      const SizedBox(height: 38),
      _TimerControlButton(
        icon: Icons.play_arrow_rounded,
        label: 'Başla',
        onTap: onStart,
      ),
    ],
  );
}

class _ActiveTimer extends StatefulWidget {
  const _ActiveTimer({
    super.key,
    required this.title,
    required this.taskIcon,
    required this.taskColor,
    required this.remainingLabel,
    required this.timeRange,
    required this.progress,
    required this.isRunning,
    required this.isFinished,
    required this.onRemoveMinute,
    required this.onAddMinute,
    required this.onToggle,
    required this.onFinish,
    required this.onComplete,
    required this.isCelebrating,
    required this.celebrationScale,
    required this.celebrationOpacity,
  });

  final String title;
  final String? taskIcon;
  final String taskColor;
  final String remainingLabel;
  final String timeRange;
  final double progress;
  final bool isRunning;
  final bool isFinished;
  final VoidCallback onRemoveMinute;
  final VoidCallback onAddMinute;
  final VoidCallback onToggle;
  final VoidCallback onFinish;
  final VoidCallback onComplete;
  final bool isCelebrating;
  final Animation<double> celebrationScale;
  final Animation<double> celebrationOpacity;

  @override
  State<_ActiveTimer> createState() => _ActiveTimerState();
}

class _ActiveTimerState extends State<_ActiveTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _returnController;

  @override
  void initState() {
    super.initState();
    _returnController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          setState(() {
            _displayProgress =
                _returnFrom +
                (_returnTo - _returnFrom) * _returnController.value;
          });
        });
  }

  @override
  void didUpdateWidget(covariant _ActiveTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress == widget.progress ||
        !_returnController.isAnimating) {
      return;
    }

    // Süre değiştiğinde (ör. +1 dk) yarım kalan geri dönüş animasyonu da
    // artık eski konuma değil güncel zaman ilerlemesine bağlanır.
    _returnFrom = _displayProgress ?? oldWidget.progress;
    _returnTo = widget.progress;
    _returnController.forward(from: 0);
  }

  double? _displayProgress;
  double _returnFrom = 0;
  double _returnTo = 0;
  double _lastAngle = 0;
  double _rotation = 0;
  double _baseProgress = 0;
  bool _completedRotation = false;

  @override
  void dispose() {
    _returnController.dispose();
    super.dispose();
  }

  double _angleFor(Offset position, Size size) {
    final center = size.center(Offset.zero);
    return math.atan2(position.dy - center.dy, position.dx - center.dx);
  }

  void _startRotation(Offset position, Size size) {
    _returnController.stop();
    _lastAngle = _angleFor(position, size);
    _rotation = 0;
    _baseProgress = widget.progress;
    _completedRotation = false;
    setState(() => _displayProgress = _baseProgress);
  }

  void _updateRotation(Offset position, Size size) {
    final angle = _angleFor(position, size);
    var delta = angle - _lastAngle;
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;
    _lastAngle = angle;
    final maxRotation = (1 - _baseProgress) * math.pi * 2;
    _rotation = (_rotation + delta).clamp(0, maxRotation);
    final completed = maxRotation == 0 || _rotation >= maxRotation;
    if (completed && !_completedRotation) {
      _completedRotation = true;
      unawaited(HapticFeedback.mediumImpact());
    }
    setState(() {
      _displayProgress = (_baseProgress + _rotation / (math.pi * 2)).clamp(
        0,
        1,
      );
    });
  }

  void _endRotation() {
    final maxRotation = (1 - _baseProgress) * math.pi * 2;
    final endedAtCompletion =
        maxRotation == 0 || _rotation >= maxRotation - .0001;
    if (endedAtCompletion) {
      widget.onComplete();
      return;
    }
    _returnToTimerProgress();
  }

  void _cancelRotation() {
    _returnToTimerProgress();
  }

  void _returnToTimerProgress() {
    _returnFrom = _displayProgress ?? widget.progress;
    _returnTo = widget.progress;
    _returnController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _displayProgress = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPaused =
        !widget.isRunning && !widget.isFinished && !widget.isCelebrating;
    return Column(
      children: [
        const SizedBox(height: 72),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: widget.isCelebrating
              ? _FocusCompletionHeading(
                  key: const ValueKey('focus-completion-heading'),
                )
              : Column(
                  key: const ValueKey('active-focus-heading'),
                  children: [
                    Text(
                      widget.title,
                      key: const ValueKey('active-focus-title'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontSize: 38,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.timeRange,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 22),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: widget.celebrationScale,
              child: _TimerDial(
                key: const ValueKey('active-focus-dial'),
                progress: _displayProgress ?? widget.progress,
                showHandle: true,
                paused: isPaused,
                onRotationStart: _startRotation,
                onRotationUpdate: _updateRotation,
                onRotationEnd: _endRotation,
                onRotationCancel: _cancelRotation,
                child: AnimatedContainer(
                  key: const ValueKey('active-focus-icon-circle'),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 212,
                  height: 212,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.taskIcon == null
                        ? const Color(0xFFFFDFC5)
                        : FlorienColors.fromHex(
                            widget.taskColor,
                          ).withValues(alpha: .18),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isPaused ? .72 : 1,
                        child: widget.taskIcon == null
                            ? Icon(
                                Icons.hourglass_bottom_rounded,
                                key: const ValueKey('active-focus-task-icon'),
                                size: 94,
                                color: const Color(0xFF9A6037),
                              )
                            : TaskIconBadge.forTask(
                                icon: widget.taskIcon!,
                                size: 148,
                                iconSize: 112,
                                circular: true,
                                iconKey: const ValueKey(
                                  'active-focus-task-icon',
                                ),
                              ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          child: isPaused
                              ? Container(
                                  key: const ValueKey('focus-paused-indicator'),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.palette.surface,
                                    border: Border.all(
                                      color: context.palette.border,
                                      width: FlorienBorders.thin,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.pause_rounded,
                                    size: 20,
                                    color: context.palette.textSecondary,
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('focus-running-indicator'),
                                  width: 38,
                                  height: 38,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.isCelebrating)
              _FocusDialCelebration(
                opacity: widget.celebrationOpacity,
                scale: widget.celebrationScale,
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          widget.remainingLabel,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: 52,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: widget.isCelebrating
              ? const SizedBox(
                  key: ValueKey('focus-timer-controls-hidden'),
                  height: 54,
                )
              : Column(
                  key: const ValueKey('focus-timer-controls'),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: widget.onRemoveMinute,
                          child: const Text(
                            '− 1 dk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TimerControlButton(
                          icon: widget.isFinished
                              ? Icons.replay_rounded
                              : widget.isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: '',
                          onTap: widget.isFinished
                              ? widget.onFinish
                              : widget.onToggle,
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: widget.onAddMinute,
                          child: const Text(
                            '+ 1 dk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      key: const ValueKey('finish-focus-session'),
                      onPressed: widget.onFinish,
                      icon: const Icon(Icons.stop_circle_outlined, size: 19),
                      label: const Text(
                        'Sonlandır',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FocusDialCelebration extends StatelessWidget {
  const _FocusDialCelebration({required this.opacity, required this.scale});

  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: FadeTransition(
      opacity: opacity,
      child: SizedBox.square(
        key: const ValueKey('focus-dial-celebration'),
        dimension: 310,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: scale,
              child: Container(
                width: 268,
                height: 268,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlorienColors.success.withValues(alpha: .12),
                  border: Border.all(
                    color: FlorienColors.success.withValues(alpha: .35),
                    width: FlorienBorders.medium,
                  ),
                ),
              ),
            ),
            ScaleTransition(
              scale: scale,
              child: Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.surface.withValues(alpha: .9),
                  border: Border.all(
                    color: context.palette.border,
                    width: FlorienBorders.thin,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: FlorienColors.success.withValues(alpha: .2),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 84,
                  color: FlorienColors.success,
                ),
              ),
            ),
            const Positioned(top: 36, left: 68, child: _FocusSparkle(size: 24)),
            const Positioned(
              top: 64,
              right: 49,
              child: _FocusSparkle(size: 18),
            ),
            const Positioned(
              bottom: 56,
              left: 48,
              child: _FocusSparkle(size: 16),
            ),
            const Positioned(
              bottom: 38,
              right: 68,
              child: _FocusSparkle(size: 25),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FocusCompletionHeading extends StatelessWidget {
  const _FocusCompletionHeading({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'Harika iş!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Odak turun tamamlandı',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _FocusSparkle extends StatelessWidget {
  const _FocusSparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.auto_awesome_rounded,
    size: size,
    color: FlorienColors.focusAccent,
  );
}

class _FocusTitle extends StatelessWidget {
  const _FocusTitle();

  @override
  Widget build(BuildContext context) => Text(
    'Odaklan',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
      fontSize: 38,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.2,
    ),
  );
}

class _TimerDial extends StatelessWidget {
  const _TimerDial({
    super.key,
    required this.progress,
    required this.child,
    this.showHandle = false,
    this.showDurationLabels = false,
    this.paused = false,
    this.onRotationStart,
    this.onRotationUpdate,
    this.onRotationEnd,
    this.onRotationCancel,
  });

  final double progress;
  final Widget child;
  final bool showHandle;
  final bool showDurationLabels;
  final bool paused;
  final void Function(Offset, Size)? onRotationStart;
  final void Function(Offset, Size)? onRotationUpdate;
  final VoidCallback? onRotationEnd;
  final VoidCallback? onRotationCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, 310.0);
      final dialAccent = paused
          ? context.palette.textSecondary
          : FlorienColors.focusAccent;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onRotationStart == null
            ? null
            : (event) =>
                  onRotationStart!(event.localPosition, Size.square(size)),
        onPointerMove: onRotationUpdate == null
            ? null
            : (event) =>
                  onRotationUpdate!(event.localPosition, Size.square(size)),
        onPointerUp: onRotationEnd == null ? null : (_) => onRotationEnd!(),
        onPointerCancel: onRotationCancel == null
            ? null
            : (_) => onRotationCancel!(),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _SimpleDialPainter(
              progress: progress,
              trackColor: context.palette.surfaceMuted,
              tickColor: dialAccent,
              progressColor: dialAccent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showDurationLabels) ...[
                  const Positioned(top: 42, child: _DialLabel(label: '60')),
                  const Positioned(right: 35, child: _DialLabel(label: '15')),
                  const Positioned(bottom: 42, child: _DialLabel(label: '30')),
                  const Positioned(left: 35, child: _DialLabel(label: '45')),
                ],
                if (showHandle)
                  Positioned(
                    left:
                        size / 2 +
                        math.cos(-math.pi / 2 + math.pi * 2 * progress) *
                            (size / 2 - 22) -
                        19,
                    top:
                        size / 2 +
                        math.sin(-math.pi / 2 + math.pi * 2 * progress) *
                            (size / 2 - 22) -
                        19,
                    child: IgnorePointer(
                      child: Container(
                        key: const ValueKey('focus-dial-handle'),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: dialAccent.withValues(alpha: .22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dialAccent.withValues(alpha: .55),
                          ),
                        ),
                        child: Icon(
                          Icons.rotate_right_rounded,
                          size: 20,
                          color: dialAccent,
                        ),
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DurationMenuButton extends StatelessWidget {
  const _DurationMenuButton({required this.onSelected});

  final Future<void> Function(int minutes) onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    shape: StadiumBorder(side: BorderSide(color: context.palette.border)),
    child: PopupMenuButton<int>(
      tooltip: 'Odaklanma süresi seç',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      useRootNavigator: true,
      onSelected: (value) {
        onSelected(value);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 5, child: _DurationMenuItem(5, '5 dk.')),
        PopupMenuItem(value: 10, child: _DurationMenuItem(10, '10 dk.')),
        PopupMenuItem(value: 15, child: _DurationMenuItem(15, '15 dk.')),
        PopupMenuItem(value: 30, child: _DurationMenuItem(30, '30 dk.')),
        PopupMenuItem(value: 45, child: _DurationMenuItem(45, '45 dk.')),
        PopupMenuItem(value: 60, child: _DurationMenuItem(60, '1 saat')),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 22),
              SizedBox(width: 14),
              Text('Özel'),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 19),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'Odaklanmaya başla',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DurationMenuItem extends StatelessWidget {
  const _DurationMenuItem(this.minutes, this.label);

  final int minutes;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.palette.textSecondary, width: 1.5),
        ),
        child: Text(
          '$minutes',
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: minutes > 9 ? 9 : 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Text(label),
    ],
  );
}

class _AlarmToggleButton extends StatelessWidget {
  const _AlarmToggleButton({
    required this.enabled,
    required this.available,
    required this.onTap,
  });

  final bool enabled;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: enabled,
    label: !available
        ? 'Alarm Premium'
        : (enabled ? 'Alarm açık' : 'Alarm kapalı'),
    child: Material(
      color: enabled
          ? Theme.of(context).colorScheme.primaryContainer
          : context.palette.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: enabled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .35)
              : context.palette.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                !available
                    ? Icons.lock_outline_rounded
                    : enabled
                    ? Icons.alarm_on_rounded
                    : Icons.alarm_off_rounded,
                size: 19,
                color: enabled
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : context.palette.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                !available
                    ? 'Alarm Premium'
                    : enabled
                    ? 'Alarm açık'
                    : 'Alarm kapalı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : context.palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FocusMusicMenuButton extends StatelessWidget {
  const _FocusMusicMenuButton({
    required this.selectedMusic,
    required this.autoPlay,
    required this.isPlaying,
    required this.onSelected,
  });

  final _FocusMusicTrack? selectedMusic;
  final bool autoPlay;
  final bool isPlaying;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('focus-music-menu'),
    tooltip: 'Odak müziğini ayarla',
    position: PopupMenuPosition.under,
    offset: const Offset(0, 5),
    color: context.palette.surface,
    elevation: 2,
    surfaceTintColor: Colors.transparent,
    constraints: const BoxConstraints(minWidth: 232, maxWidth: 268),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    onSelected: onSelected,
    itemBuilder: (context) => [
      for (final track in _focusMusicTracks)
        PopupMenuItem<String>(
          value: _FocusMusicMenuValue.track(track.id),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: _MusicMenuItemContent(
            icon: Icons.music_note_rounded,
            label: track.title,
            selected: selectedMusic?.id == track.id,
          ),
        ),
      PopupMenuItem<String>(
        value: _FocusMusicMenuValue.none,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: _MusicMenuItemContent(
          icon: Icons.music_off_rounded,
          label: 'Müzik yok',
          selected: selectedMusic == null,
        ),
      ),
      const PopupMenuDivider(height: 9),
      PopupMenuItem<String>(
        value: autoPlay
            ? _FocusMusicMenuValue.autoPlayOff
            : _FocusMusicMenuValue.autoPlayOn,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: _MusicMenuItemContent(
          icon: Icons.play_circle_outline_rounded,
          label: 'Otomatik oynat',
          selected: false,
          trailing: IgnorePointer(
            child: Switch.adaptive(
              value: autoPlay,
              onChanged: (_) {},
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    ],
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 178),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.palette.surfaceMuted,
          shape: StadiumBorder(side: BorderSide(color: context.palette.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                size: 19,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  selectedMusic?.title ?? 'Müzik',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MusicMenuItemContent extends StatelessWidget {
  const _MusicMenuItemContent({
    required this.icon,
    required this.label,
    required this.selected,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : context.palette.textSecondary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          SizedBox(width: 38, height: 28, child: FittedBox(child: trailing))
        else if (selected)
          Icon(
            Icons.check_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
      ],
    ),
  );
}

class _FocusMusicTrack {
  const _FocusMusicTrack({
    required this.id,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String assetPath;
}

abstract final class _FocusMusicMenuValue {
  static const none = 'music:none';
  static const autoPlayOn = 'autoplay:on';
  static const autoPlayOff = 'autoplay:off';

  static String track(String id) => 'music:$id';
}

const _focusMusicTracks = <_FocusMusicTrack>[
  _FocusMusicTrack(
    id: 'gece-akisi',
    title: 'Gece Akışı',
    assetPath: 'assets/focus_music/01-gece-akisi.m4a',
  ),
  _FocusMusicTrack(
    id: 'gun-isigi',
    title: 'Gün Işığı',
    assetPath: 'assets/focus_music/02-gun-isigi.m4a',
  ),
  _FocusMusicTrack(
    id: 'sessiz-odak',
    title: 'Sessiz Odak',
    assetPath: 'assets/focus_music/03-sessiz-odak.m4a',
  ),
  _FocusMusicTrack(
    id: 'hizli-baslangic',
    title: 'Hızlı Başlangıç',
    assetPath: 'assets/focus_music/04-hizli-baslangic.m4a',
  ),
  _FocusMusicTrack(
    id: 'derin-akis',
    title: 'Derin Akış',
    assetPath: 'assets/focus_music/05-derin-akis.m4a',
  ),
  _FocusMusicTrack(
    id: 'kafa-toparlama',
    title: 'Kafa Toparlama',
    assetPath: 'assets/focus_music/06-kafa-toparlama.m4a',
  ),
];

class _TimerControlButton extends StatelessWidget {
  const _TimerControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      minimumSize: Size(compact ? 92 : 154, 52),
      backgroundColor: context.palette.surface,
      foregroundColor: context.palette.textPrimary,
      side: BorderSide(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
      shape: const StadiumBorder(),
    ),
    icon: Icon(icon, size: 26),
    label: label.isEmpty
        ? const SizedBox.shrink()
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class _DialLabel extends StatelessWidget {
  const _DialLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: context.palette.textSecondary,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _SimpleDialPainter extends CustomPainter {
  const _SimpleDialPainter({
    required this.progress,
    required this.trackColor,
    required this.tickColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color tickColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 22;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      start,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = progressColor.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round,
    );

    final ticks = math.max(1, (60 * progress).round());
    final tickPaint = Paint()
      ..color = tickColor.withValues(alpha: .32)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var index = 1; index < ticks; index++) {
      final angle = start + math.pi * 2 * index / 60;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 9),
        center.dy + math.sin(angle) * (radius - 9),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 9),
        center.dy + math.sin(angle) * (radius + 9),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.progressColor != progressColor;
}
