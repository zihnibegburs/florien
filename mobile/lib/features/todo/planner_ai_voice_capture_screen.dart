import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:florien/core/services/speech_input_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_ai_animation.dart';

class PlannerAiVoiceCaptureScreen extends StatefulWidget {
  const PlannerAiVoiceCaptureScreen({super.key});

  @override
  State<PlannerAiVoiceCaptureScreen> createState() =>
      _PlannerAiVoiceCaptureScreenState();
}

class _PlannerAiVoiceCaptureScreenState
    extends State<PlannerAiVoiceCaptureScreen>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechInputService();
  late final AnimationController _waveController;

  bool _isListening = false;
  double _soundLevel = 0.12;
  String _transcript = '';
  String _status = 'Mikrofon açılıyor…';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  @override
  void dispose() {
    _waveController.dispose();
    unawaited(_speech.dispose());
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    setState(() => _status = 'Seni dinliyorum…');
    await _speech.start(
      onText: (text) {
        if (mounted) setState(() => _transcript = text);
      },
      onListeningChanged: (isListening) {
        if (!mounted) return;
        setState(() {
          _isListening = isListening;
          _status = isListening
              ? 'Seni dinliyorum…'
              : _transcript.isEmpty
              ? 'Tekrar denemek için ikona dokun.'
              : 'Hazır olduğunda metni ekle.';
        });
      },
      onSoundLevelChanged: _updateSoundLevel,
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _status = message;
        });
      },
    );
  }

  void _updateSoundLevel(double level) {
    final normalized = level < 0
        ? ((level + 55) / 55).clamp(0.08, 1.0)
        : (level / 18).clamp(0.08, 1.0);
    if (!mounted) return;
    setState(() {
      _soundLevel = normalized;
      _waveController.duration = Duration(
        milliseconds: 1420 - (normalized * 940).round(),
      );
    });
  }

  Future<void> _finish() async {
    await _speech.stop();
    if (mounted) Navigator.of(context).pop(_transcript.trim());
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      return;
    }
    await _startListening();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FlorienTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leadingWidth: 72,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: IconButton(
                tooltip: 'Sohbete dön',
                onPressed: _finish,
                style: IconButton.styleFrom(
                  backgroundColor: context.palette.surface,
                  foregroundColor: context.palette.textPrimary,
                  side: BorderSide(
                    color: context.palette.border,
                    width: FlorienBorders.thin,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            title: const Text('Sesli planlama'),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  _isListening ? 'Konuşabilirsin' : 'Hazır olduğunda konuş',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) => CustomPaint(
                            painter: _VoiceWavePainter(
                              phase: _waveController.value,
                              energy: _isListening ? _soundLevel : 0.05,
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: _isListening
                            ? 'Dinlemeyi durdur'
                            : 'Dinlemeyi başlat',
                        child: GestureDetector(
                          key: const ValueKey('planner-ai-voice-orb'),
                          onTap: _toggleListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: _isListening ? 126 : 112,
                            height: _isListening ? 126 : 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  FlorienColors.paleBlue,
                                  FlorienColors.aiAccent,
                                  FlorienColors.softLime,
                                ],
                              ),
                              border: Border.all(
                                color: context.palette.textPrimary,
                                width: FlorienBorders.thin,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: FlorienColors.aiAccent.withValues(
                                    alpha: _isListening ? 0.45 : 0.2,
                                  ),
                                  blurRadius: _isListening ? 36 : 16,
                                  spreadRadius: _isListening ? 6 : 0,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: FlorienAiAnimation(
                                key: const ValueKey(
                                  'planner-ai-voice-animation',
                                ),
                                size: _isListening ? 116 : 102,
                                animate: _isListening,
                                speed: florienAiVoiceAnimationSpeed(
                                  isListening: _isListening,
                                  soundLevel: _soundLevel,
                                ),
                                semanticLabel: _isListening
                                    ? 'Florien AI seni dinliyor'
                                    : 'Florien AI sesli giriş',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: AnimatedOpacity(
                    opacity: _transcript.isEmpty ? 0.58 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 68),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.surface,
                        borderRadius: BorderRadius.circular(FlorienRadius.lg),
                        border: Border.all(
                          color: context.palette.border,
                          width: FlorienBorders.thin,
                        ),
                      ),
                      child: Text(
                        _transcript.isEmpty
                            ? 'Söylediklerin burada görünecek.'
                            : _transcript,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _transcript.isEmpty
                              ? context.palette.textSecondary
                              : context.palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('planner-ai-voice-finish'),
                      onPressed: _finish,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text(
                        _transcript.isEmpty
                            ? 'Sohbete dön'
                            : 'Metni sohbete ekle',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  const _VoiceWavePainter({required this.phase, required this.energy});

  final double phase;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.55;
    final amplitude = 10 + (energy * 44);
    const colors = [
      FlorienColors.paleBlue,
      FlorienColors.aiAccent,
      FlorienColors.softLime,
    ];

    for (var index = 0; index < colors.length; index++) {
      final path = Path();
      final offset = index * math.pi * 0.68;
      final multiplier = 1 - (index * 0.16);
      for (double x = 0; x <= size.width; x += 3) {
        final progress = x / size.width;
        final y =
            centerY +
            math.sin(
                  (progress * math.pi * 3.5) + (phase * math.pi * 2) + offset,
                ) *
                amplitude *
                multiplier +
            math.sin((progress * math.pi * 7) - (phase * math.pi * 2)) *
                amplitude *
                0.16;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[index].withValues(alpha: 0.66 - (index * 0.1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.energy != energy;
}
