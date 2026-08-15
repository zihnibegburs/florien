import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:florien/core/models/models.dart';

class PlannerChatTurn {
  const PlannerChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class PlannerTaskSuggestion {
  const PlannerTaskSuggestion({
    required this.title,
    required this.durationMinutes,
  });

  final String title;
  final int durationMinutes;
}

class PlannerAiException implements Exception {
  const PlannerAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlannerAiReply {
  const PlannerAiReply({required this.message, required this.tasks});

  final String message;
  final List<PlannerTaskSuggestion> tasks;
}

abstract interface class TaskBreakdownService {
  Future<List<String>> generateSubtasks(String title);
}

class FirebaseTaskBreakdownService implements TaskBreakdownService {
  const FirebaseTaskBreakdownService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<String>> generateSubtasks(String title) async {
    try {
      final result = await _functions.httpsCallable('assistBreakdown').call(
        <String, Object?>{'task': title},
      );
      final raw = result.data;
      if (raw is! Map) throw const PlannerAiException('Geçersiz AI yanıtı.');
      final steps = raw['steps'] as List? ?? const [];
      final titles = steps
          .whereType<Map>()
          .map((step) => (step['title']?.toString() ?? '').trim())
          .where((title) => title.isNotEmpty)
          .take(TaskModel.aiSubtaskLimit)
          .toList(growable: false);
      if (titles.isEmpty) {
        throw const PlannerAiException('AI alt görev üretemedi.');
      }
      return titles;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'assistBreakdown failed: ${error.code} ${error.message}\n$stackTrace',
      );
      throw PlannerAiException(_breakdownMessageFor(error));
    }
  }
}

abstract interface class PlannerAiGateway {
  Future<PlannerAiReply> send(List<PlannerChatTurn> conversation);
}

class FirebasePlannerAiGateway implements PlannerAiGateway {
  const FirebasePlannerAiGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<PlannerAiReply> send(List<PlannerChatTurn> conversation) async {
    final callable = _functions.httpsCallable('assistPlannerChat');
    late final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call(<String, Object?>{
        'messages': conversation.map((turn) => turn.toJson()).toList(),
      });
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'assistPlannerChat failed: ${error.code} ${error.message}\n$stackTrace',
      );
      throw PlannerAiException(_messageFor(error));
    }
    final raw = result.data;
    if (raw is! Map) {
      throw const PlannerAiException(
        'Şu anda plan asistanına bağlanamadım. Biraz sonra tekrar deneyebilir misin?',
      );
    }
    final data = Map<String, dynamic>.from(raw);
    final tasksRaw = data['tasks'] as List? ?? const [];
    final tasks = tasksRaw
        .map((node) {
          final item = Map<String, dynamic>.from(node as Map);
          final title = (item['title'] as String? ?? '').trim();
          if (title.isEmpty) return null;
          final duration = (item['durationMinutes'] as num?)?.toInt() ?? 30;
          return PlannerTaskSuggestion(
            title: title,
            durationMinutes: duration.clamp(5, 24 * 60),
          );
        })
        .whereType<PlannerTaskSuggestion>()
        .toList(growable: false);
    final message = (data['reply']?.toString() ?? '').trim();
    return PlannerAiReply(
      message: message.isEmpty
          ? 'Planlamak istediğin şeyi biraz daha anlatır mısın?'
          : message,
      tasks: tasks,
    );
  }
}

String _messageFor(FirebaseFunctionsException error) {
  return switch (error.code) {
    'unauthenticated' => 'Plan asistanı için giriş yapmış olman gerekiyor.',
    'not-found' =>
      'Plan asistanı fonksiyonu bulunamadı. Firebase Functions henüz deploy edilmemiş olabilir.',
    'failed-precondition' =>
      'Plan asistanı API anahtarı (GROQ_API_KEY) yapılandırılmamış.',
    'unavailable' || 'deadline-exceeded' =>
      'Plan asistanı şu anda yanıt vermiyor. Biraz sonra tekrar dene.',
    _ =>
      'Şu anda plan asistanına bağlanamadım. Biraz sonra tekrar deneyebilir misin?',
  };
}

String _breakdownMessageFor(FirebaseFunctionsException error) {
  return switch (error.code) {
    'unauthenticated' => 'AI alt görevleri için giriş yapmış olman gerekiyor.',
    'not-found' =>
      'AI alt görev fonksiyonu bulunamadı. Firebase Functions henüz deploy edilmemiş olabilir.',
    'failed-precondition' => 'AI alt görevleri şu an yapılandırılmamış.',
    'unavailable' || 'deadline-exceeded' =>
      'AI alt görevleri şu an yanıt vermiyor. Biraz sonra tekrar dene.',
    _ => 'AI alt görevleri şu an oluşturamadı. Tekrar deneyebilirsin.',
  };
}
