import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechTextField extends ConsumerStatefulWidget {
  const SpeechTextField({
    super.key,
    required this.controller,
    this.maxLines = 1,
    this.decoration,
    this.onChanged,
  });

  final TextEditingController controller;
  final int maxLines;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<SpeechTextField> createState() => _SpeechTextFieldState();
}

class _SpeechTextFieldState extends ConsumerState<SpeechTextField> {
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _textBeforeListen = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _textBeforeListen = widget.controller.text;
    if (_textBeforeListen.isNotEmpty && !_textBeforeListen.endsWith(' ')) {
      _textBeforeListen = '$_textBeforeListen ';
    }

    final lang = ref.read(appLanguageProvider).valueOrNull ?? 'tr';
    final locales = await _speech.locales();
    String? locale;
    for (final l in locales) {
      if (l.localeId.startsWith(lang)) {
        locale = l.localeId;
        break;
      }
    }

    final started = await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: locale,
      ),
    );

    if (mounted) setState(() => _isListening = started);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final spoken = result.recognizedWords.trim();
    if (spoken.isEmpty) return;

    final text = '$_textBeforeListen$spoken';
    widget.controller.value = widget.controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return TextField(
      controller: widget.controller,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        suffixIcon: _speechAvailable
            ? IconButton(
                tooltip: _isListening ? s.stopListening : s.speakToType,
                onPressed: _toggleListening,
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red.shade50
                        : FlorienColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? Colors.red.shade400 : FlorienColors.primary,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
