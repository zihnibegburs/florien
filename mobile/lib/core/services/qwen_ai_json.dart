import 'dart:convert';

import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/planner_ai_service.dart';

Map<String, dynamic>? extractJsonObject(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
  final fenced = fence.firstMatch(text);
  if (fenced != null) {
    text = (fenced.group(1) ?? '').trim();
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

PlannerAiReply parseQwenPlannerChat(String raw) {
  final data = extractJsonObject(raw);
  if (data == null) {
    final fallback = raw.trim();
    return PlannerAiReply(
      message: fallback.isEmpty
          ? ActiveLanguage.s(
              'Planlamak istediğin şeyi biraz daha anlatır mısın?',
            )
          : fallback,
      tasks: const [],
    );
  }
  final tasksRaw = data['tasks'] is List ? data['tasks'] as List : const [];
  final tasks = tasksRaw
      .whereType<Map>()
      .map((node) {
        final item = Map<String, dynamic>.from(node);
        final title = item['title']?.toString().trim() ?? '';
        if (title.isEmpty) return null;
        final duration = (item['durationMinutes'] as num?)?.toInt() ?? 30;
        return PlannerTaskSuggestion(
          title: title,
          durationMinutes: duration.clamp(5, 24 * 60),
        );
      })
      .whereType<PlannerTaskSuggestion>()
      .take(8)
      .toList(growable: false);
  final message = (data['reply']?.toString() ?? '').trim();
  return PlannerAiReply(
    message: message.isEmpty
        ? ActiveLanguage.s('Planlamak istediğin şeyi biraz daha anlatır mısın?')
        : message,
    tasks: tasks,
  );
}

List<String> parseQwenBreakdownSteps(String raw) {
  final data = extractJsonObject(raw);
  final steps = data == null
      ? const <dynamic>[]
      : (data['steps'] is List ? data['steps'] as List : const []);
  final titles = steps
      .map((node) {
        if (node is String) return node.trim();
        if (node is Map) {
          return (node['title']?.toString() ?? '').trim();
        }
        return '';
      })
      .where((title) => title.isNotEmpty)
      .take(TaskModel.aiSubtaskLimit)
      .toList(growable: false);
  if (titles.isEmpty) {
    throw PlannerAiException(ActiveLanguage.s('AI alt görev üretemedi.'));
  }
  return titles;
}

String buildQwenChatPrompt({
  required String systemPrompt,
  required List<PlannerChatTurn> conversation,
}) {
  final buffer = StringBuffer()
    ..writeln('<|im_start|>system')
    ..writeln(systemPrompt)
    ..writeln('<|im_end|>');
  for (final turn in conversation) {
    final role = turn.role == 'assistant' ? 'assistant' : 'user';
    buffer
      ..writeln('<|im_start|>$role')
      ..writeln(turn.content)
      ..writeln('<|im_end|>');
  }
  buffer.write('<|im_start|>assistant\n');
  return buffer.toString();
}

String qwenOutputLanguageName(String code) {
  return switch (normalizeLanguageCode(code) ?? defaultLanguageCode) {
    'tr' => 'Turkish',
    'es' => 'Spanish',
    'de' => 'German',
    'fr' => 'French',
    'pt' => 'Portuguese',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    'zh' => 'Simplified Chinese',
    'ar' => 'Arabic',
    _ => 'English',
  };
}
