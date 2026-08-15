import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';
import 'package:florien/features/providers.dart';

class FocusTimerTab extends StatefulWidget {
  const FocusTimerTab({
    super.key,
    this.launchRequest,
    this.resetSignal = 0,
    this.onStandaloneFocusStarted,
    this.onTaskProgressChanged,
    this.onTaskCompleted,
    this.onSessionClosed,
  });

  final FocusTaskLaunch? launchRequest;
  final int resetSignal;
  final Future<FocusTaskLaunch> Function(int durationMinutes)?
  onStandaloneFocusStarted;
  final ValueChanged<ActiveFocusTask?>? onTaskProgressChanged;
  final Future<void> Function(String taskId)? onTaskCompleted;
  final VoidCallback? onSessionClosed;

  @override
  State<FocusTimerTab> createState() => _FocusTimerTabState();
}

class _FocusTimerTabState extends State<FocusTimerTab>
    with SingleTickerProviderStateMixin {
  int _selectedMinutes = 5;
  int _remainingSeconds = 5 * 60;
  int _sessionTotalSeconds = 5 * 60;
  DateTime? _sessionStartedAt;
  DateTime? _plannedEndAt;
  Timer? _timer;
  bool _alarmEnabled = true;
  double _setupLastAngle = 0;
  double _setupDragProgress = 0;
  String? _taskId;
  String? _taskTitle;
  String _taskIcon = TaskIcons.defaultName;
  String _taskColor = '#6C5CE7';
  bool _taskCompletionRequested = false;
  bool _automaticTask = false;
  bool _creatingStandaloneTask = false;
  bool _isFinishing = false;
  late final AnimationController _completionController;
  late final Animation<double> _completionScale;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _completionScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.045,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.045,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 58,
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
    _completionController.dispose();
    super.dispose();
  }

  Future<void> _toggleTimer() async {
    if (_isRunning) {
      _timer?.cancel();
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
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Odaklanma görevi oluşturulamadı.')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _creatingStandaloneTask = false);
      }
    }

    final now = DateTime.now();
    _sessionStartedAt ??= now;
    _sessionTotalSeconds = _sessionActive
        ? math.max(_sessionTotalSeconds, _remainingSeconds)
        : _remainingSeconds;
    _plannedEndAt = now.add(Duration(seconds: _remainingSeconds));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _publishTaskProgress();
        final taskId = _taskId;
        if (taskId != null && !_automaticTask) {
          unawaited(_markTaskCompleted(taskId));
        }
        if (_alarmEnabled) {
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
  }

  void _closeSession() {
    _timer?.cancel();
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
      _automaticTask = false;
      _isFinishing = false;
    });
    widget.onTaskProgressChanged?.call(null);
    widget.onSessionClosed?.call();
  }

  void _startTaskFocus(FocusTaskLaunch request) {
    if (!mounted) return;
    _timer?.cancel();
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
    if (_taskCompletionRequested || widget.onTaskCompleted == null) return;
    _taskCompletionRequested = true;
    await widget.onTaskCompleted!(taskId);
    if (mounted && _taskId == taskId) {
      widget.onTaskProgressChanged?.call(null);
    }
  }

  Future<void> _completeAndCloseSession() async {
    final taskId = _taskId;
    _timer?.cancel();
    if (taskId != null) {
      setState(() => _remainingSeconds = 0);
      _publishTaskProgress();
      await _markTaskCompleted(taskId);
    }
    if (mounted) await _finishSessionWithAnimation();
  }

  Future<void> _finishSessionWithAnimation() async {
    if (_isFinishing) return;
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

    return ScaleTransition(
      scale: _completionScale,
      alignment: Alignment.center,
      child: IgnorePointer(
        ignoring: _isFinishing,
        child: SafeArea(
          child: ListView(
            physics: _sessionActive
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            children: [
              Row(
                children: [
                  _SimpleActionButton(
                    icon: Icons.music_note_rounded,
                    label: 'Ayarla',
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  if (_sessionActive)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _AlarmToggleButton(
                          enabled: _alarmEnabled,
                          onTap: () =>
                              setState(() => _alarmEnabled = !_alarmEnabled),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _DurationMenuButton(onSelected: _selectDuration),
                      ),
                    ),
                ],
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
                        onAddMinute: _addMinute,
                        onToggle: () => unawaited(_toggleTimer()),
                        onFinish: () =>
                            unawaited(_finishSessionWithAnimation()),
                        onComplete: () => unawaited(_completeAndCloseSession()),
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
    required this.onAddMinute,
    required this.onToggle,
    required this.onFinish,
    required this.onComplete,
  });

  final String title;
  final String? taskIcon;
  final String taskColor;
  final String remainingLabel;
  final String timeRange;
  final double progress;
  final bool isRunning;
  final bool isFinished;
  final VoidCallback onAddMinute;
  final VoidCallback onToggle;
  final VoidCallback onFinish;
  final VoidCallback onComplete;

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
    if (_completedRotation) {
      widget.onComplete();
      return;
    }
    _returnFrom = _displayProgress ?? widget.progress;
    _returnTo = widget.progress;
    _returnController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _displayProgress = null);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 72),
      Text(
        widget.title,
        key: const ValueKey('active-focus-title'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
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
      const SizedBox(height: 22),
      _TimerDial(
        key: const ValueKey('active-focus-dial'),
        progress: _displayProgress ?? widget.progress,
        showHandle: true,
        onRotationStart: _startRotation,
        onRotationUpdate: _updateRotation,
        onRotationEnd: _endRotation,
        child: Container(
          key: const ValueKey('active-focus-icon-circle'),
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
                  iconKey: const ValueKey('active-focus-task-icon'),
                ),
        ),
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
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: widget.onAddMinute,
            child: const Text(
              '+ 1 dk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          _TimerControlButton(
            icon: widget.isFinished
                ? Icons.replay_rounded
                : widget.isRunning
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: '',
            onTap: widget.isFinished ? widget.onFinish : widget.onToggle,
            compact: true,
          ),
        ],
      ),
    ],
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
    this.onRotationStart,
    this.onRotationUpdate,
    this.onRotationEnd,
  });

  final double progress;
  final Widget child;
  final bool showHandle;
  final bool showDurationLabels;
  final void Function(Offset, Size)? onRotationStart;
  final void Function(Offset, Size)? onRotationUpdate;
  final VoidCallback? onRotationEnd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, 310.0);
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
        onPointerCancel: onRotationEnd == null ? null : (_) => onRotationEnd!(),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _SimpleDialPainter(
              progress: progress,
              trackColor: context.palette.surfaceMuted,
              tickColor: Theme.of(context).colorScheme.primary,
              progressColor: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .35),
                          ),
                        ),
                        child: Icon(
                          Icons.rotate_right_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
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
  const _AlarmToggleButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: enabled,
    label: enabled ? 'Alarm açık' : 'Alarm kapalı',
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
                enabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                size: 19,
                color: enabled
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : context.palette.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                enabled ? 'Alarm açık' : 'Alarm kapalı',
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

class _SimpleActionButton extends StatelessWidget {
  const _SimpleActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    shape: StadiumBorder(side: BorderSide(color: context.palette.border)),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
