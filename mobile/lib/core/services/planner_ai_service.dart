import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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
