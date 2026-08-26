import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/qwen_ai_json.dart';
import 'package:path_provider/path_provider.dart';

const qwenGgufRepoId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
const qwenGgufFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
const qwenGgufUrl =
    'https://huggingface.co/$qwenGgufRepoId/resolve/main/$qwenGgufFileName';

enum QwenAiPhase { idle, downloading, loading, ready, failed }

class QwenAiStatus {
  const QwenAiStatus({
    this.phase = QwenAiPhase.idle,
    this.progress,
    this.error,
  });

  final QwenAiPhase phase;
  final double? progress;
  final String? error;

  bool get isBusy =>
      phase == QwenAiPhase.downloading || phase == QwenAiPhase.loading;
}

class QwenModelUpdate {
  const QwenModelUpdate({this.progress, this.modelPath, this.isError = false});

  final double? progress;
  final String? modelPath;
  final bool isError;

  bool get isComplete => modelPath != null && modelPath!.isNotEmpty;
}

abstract interface class QwenCompleter {
  Future<String> complete({
    required String systemPrompt,
    required List<PlannerChatTurn> conversation,
  });
}

abstract interface class QwenModelStore {
  Stream<QwenModelUpdate> acquire(String outputDir);
  void dispose();
}

class HuggingFaceQwenModelStore implements QwenModelStore {
  static const _readyBytes = 300 * 1024 * 1024;

  @override
  Stream<QwenModelUpdate> acquire(String outputDir) async* {
    final file = File('$outputDir/$qwenGgufFileName');
    if (await file.exists() && await file.length() >= _readyBytes) {
      yield QwenModelUpdate(progress: 1, modelPath: file.path);
      return;
    }
    await Directory(outputDir).create(recursive: true);
    final part = File('${file.path}.part');
    var downloaded = 0;
    if (await part.exists()) {
      downloaded = await part.length();
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 10);
    try {
      final request = await client.getUrl(Uri.parse(qwenGgufUrl));
      if (downloaded > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$downloaded-');
      }
      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 206) {
        yield const QwenModelUpdate(isError: true);
        return;
      }
      if (response.statusCode == 200 && downloaded > 0) {
        downloaded = 0;
        await part.writeAsBytes(const []);
      }
      final total =
          downloaded +
          (response.contentLength < 0 ? 0 : response.contentLength);
      final sink = part.openWrite(mode: FileMode.append);
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          downloaded += chunk.length;
          yield QwenModelUpdate(
            progress: total == 0 ? null : (downloaded / total).clamp(0, 1),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      await part.rename(file.path);
      yield QwenModelUpdate(progress: 1, modelPath: file.path);
    } catch (_) {
      yield const QwenModelUpdate(isError: true);
    } finally {
      client.close(force: true);
    }
  }

  @override
  void dispose() {}
}

class LlamaChannelCompleter implements QwenCompleter {
  LlamaChannelCompleter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('florien/llama');

  final MethodChannel _channel;
  String? _loadedPath;

  Future<void> load(String modelPath, {required int nGpuLayers}) async {
    if (_loadedPath == modelPath) return;
    try {
      await _channel.invokeMethod<void>('load', {
        'path': modelPath,
        'nGpuLayers': nGpuLayers,
      });
      _loadedPath = modelPath;
    } on MissingPluginException {
      throw PlannerAiException(
        ActiveLanguage.s('AI modeli yüklenemedi. Tekrar deneyebilirsin.'),
      );
    } on PlatformException catch (error) {
      throw PlannerAiException(
        error.message ??
            ActiveLanguage.s('AI modeli yüklenemedi. Tekrar deneyebilirsin.'),
      );
    }
  }

  @override
  Future<String> complete({
    required String systemPrompt,
    required List<PlannerChatTurn> conversation,
  }) async {
    try {
      final text = await _channel.invokeMethod<String>('complete', {
        'prompt': buildQwenChatPrompt(
          systemPrompt: systemPrompt,
          conversation: conversation,
        ),
        'maxTokens': 280,
      });
      return text ?? '';
    } on MissingPluginException {
      throw PlannerAiException(
        ActiveLanguage.s('AI modeli yüklenemedi. Tekrar deneyebilirsin.'),
      );
    } on PlatformException catch (error) {
      throw PlannerAiException(
        error.message ??
            ActiveLanguage.s('AI modeli yüklenemedi. Tekrar deneyebilirsin.'),
      );
    }
  }
}

class QwenOnDeviceAi extends ChangeNotifier
    implements PlannerAiGateway, TaskBreakdownService {
  QwenOnDeviceAi({
    QwenCompleter? completer,
    QwenModelStore? models,
    Future<Directory> Function()? documentsDirectory,
    int? nGpuLayers,
  }) : _completer = completer ?? LlamaChannelCompleter(),
       _models = models ?? HuggingFaceQwenModelStore(),
       _documentsDirectory = documentsDirectory,
       _nGpuLayers = nGpuLayers;

  final QwenCompleter _completer;
  final QwenModelStore _models;
  final Future<Directory> Function()? _documentsDirectory;
  final int? _nGpuLayers;

  QwenAiStatus _status = const QwenAiStatus();
  Future<void>? _ready;

  QwenAiStatus get status => _status;

  void _setStatus(QwenAiStatus next) {
    _status = next;
    notifyListeners();
  }

  Future<void> ensureReady() => _ready ??= _prepare();

  Future<void> _prepare() async {
    try {
      _setStatus(const QwenAiStatus(phase: QwenAiPhase.downloading));
      final dir = await _modelDirectory();
      await dir.create(recursive: true);
      String? modelPath;
      await for (final update in _models.acquire(dir.path)) {
        if (update.isError) {
          throw PlannerAiException(
            ActiveLanguage.s(
              'AI modeli indirilemedi. İnternetini kontrol edip tekrar dene.',
            ),
          );
        }
        _setStatus(
          QwenAiStatus(
            phase: QwenAiPhase.downloading,
            progress: update.progress,
          ),
        );
        if (update.isComplete) modelPath = update.modelPath;
      }
      if (modelPath == null || modelPath.isEmpty) {
        throw PlannerAiException(
          ActiveLanguage.s(
            'AI modeli indirilemedi. İnternetini kontrol edip tekrar dene.',
          ),
        );
      }
      _setStatus(const QwenAiStatus(phase: QwenAiPhase.loading));
      final llama = _completer;
      if (llama is LlamaChannelCompleter) {
        await llama.load(modelPath, nGpuLayers: _resolvedGpuLayers);
      }
      _setStatus(const QwenAiStatus(phase: QwenAiPhase.ready));
    } catch (error) {
      _ready = null;
      final message = error is PlannerAiException
          ? error.message
          : ActiveLanguage.s('AI modeli yüklenemedi. Tekrar deneyebilirsin.');
      _setStatus(QwenAiStatus(phase: QwenAiPhase.failed, error: message));
      throw PlannerAiException(message);
    }
  }

  int get _resolvedGpuLayers => _nGpuLayers ?? 99;

  Future<Directory> _modelDirectory() async {
    if (_documentsDirectory != null) return _documentsDirectory();
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/qwen');
  }

  @override
  Future<PlannerAiReply> send(List<PlannerChatTurn> conversation) async {
    await ensureReady();
    final language = qwenOutputLanguageName(ActiveLanguage.code);
    final raw = await _completer.complete(
      systemPrompt:
          'You output JSON only. Language: $language. '
          '{"reply":"short warm reply","tasks":[{"title":"task","durationMinutes":30}]}. '
          'One task per distinct activity. Do not split one activity into prep/steps. '
          'Max 8 tasks. Never claim you saved tasks.',
      conversation: trimConversationForAiRequest(conversation),
    );
    return parseQwenPlannerChat(raw);
  }

  @override
  Future<List<String>> generateSubtasks(String title) async {
    await ensureReady();
    final language = qwenOutputLanguageName(ActiveLanguage.code);
    final raw = await _completer.complete(
      systemPrompt:
          'You output JSON only. Language: $language. '
          '{"steps":[{"title":"small step","durationMinutes":15}]}. '
          'Max 5 ADHD-friendly steps. No extra text.',
      conversation: [PlannerChatTurn(role: 'user', content: title)],
    );
    return parseQwenBreakdownSteps(raw);
  }

  @override
  void dispose() {
    _models.dispose();
    super.dispose();
  }
}
