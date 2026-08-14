import 'package:cloud_functions/cloud_functions.dart';

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
    final result = await callable.call(<String, Object?>{
      'messages': conversation.map((turn) => turn.toJson()).toList(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
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
