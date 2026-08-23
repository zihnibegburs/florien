import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/l10n/app_strings.dart';

const _maxAiInputCharacters = 2000;
const _maxAiChatTurns = 4;

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

class AiChatUsage {
  const AiChatUsage({
    required this.usedThisMonth,
    required this.limitThisMonth,
    this.resetsAt,
    this.isPremium = false,
  });

  final int usedThisMonth;
  final int limitThisMonth;
  final DateTime? resetsAt;
  final bool isPremium;

  int get remaining =>
      (limitThisMonth - usedThisMonth).clamp(0, limitThisMonth);

  bool get isExhausted => limitThisMonth > 0 && usedThisMonth >= limitThisMonth;

  static AiChatUsage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final used = (raw['usedThisMonth'] as num?)?.toInt();
    final limit = (raw['limitThisMonth'] as num?)?.toInt();
    if (used == null || limit == null) return null;
    return AiChatUsage(
      usedThisMonth: used.clamp(0, 1 << 30),
      limitThisMonth: limit.clamp(0, 1 << 30),
      resetsAt: DateTime.tryParse(raw['resetsAt']?.toString() ?? ''),
      isPremium: raw['isPremium'] == true,
    );
  }
}

class PlannerAiException implements Exception {
  const PlannerAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlannerAiReply {
  const PlannerAiReply({
    required this.message,
    required this.tasks,
    this.usage,
  });

  final String message;
  final List<PlannerTaskSuggestion> tasks;
  final AiChatUsage? usage;
}

abstract interface class TaskBreakdownService {
  Future<List<String>> generateSubtasks(String title);
}

List<String> selectAiSubtaskAdditions({
  required Iterable<String> generated,
  required Iterable<String> existing,
}) {
  final existingTitles = existing.toList(growable: false);
  final seen = existingTitles.map((item) => item.toLowerCase()).toSet();
  final remaining = TaskModel.userSubtaskLimit - existingTitles.length;
  if (remaining <= 0) return const [];
  final limit = remaining < TaskModel.aiSubtaskLimit
      ? remaining
      : TaskModel.aiSubtaskLimit;
  return generated
      .where((item) => seen.add(item.toLowerCase()))
      .take(limit)
      .toList();
}

class FirebaseTaskBreakdownService implements TaskBreakdownService {
  const FirebaseTaskBreakdownService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<String>> generateSubtasks(String title) async {
    try {
      final result = await _functions
          .httpsCallable(
            'assistBreakdown',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
          )
          .call(<String, Object?>{'task': title});
      final raw = result.data;
      if (raw is! Map)
        throw PlannerAiException(ActiveLanguage.s('Geçersiz AI yanıtı.'));
      final steps = raw['steps'] as List? ?? const [];
      final titles = steps
          .whereType<Map>()
          .map((step) => (step['title']?.toString() ?? '').trim())
          .where((title) => title.isNotEmpty)
          .take(TaskModel.aiSubtaskLimit)
          .toList(growable: false);
      if (titles.isEmpty) {
        throw PlannerAiException(ActiveLanguage.s('AI alt görev üretemedi.'));
      }
      return titles;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'assistBreakdown failed: ${error.code} ${error.message}\n$stackTrace',
      );
      throw PlannerAiException(
        aiFunctionsErrorMessage(
          code: error.code,
          details: error.details,
          breakdown: true,
        ),
      );
    } on PlannerAiException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('assistBreakdown response failed: $error\n$stackTrace');
      throw PlannerAiException(
        ActiveLanguage.s(
          'AI alt görevleri şu an oluşturamadı. Tekrar deneyebilirsin.',
        ),
      );
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
    final callable = _functions.httpsCallable(
      'assistPlannerChat',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
    );
    late final HttpsCallableResult<dynamic> result;
    try {
      final payloadTurns = trimConversationForAiRequest(conversation);
      result = await callable.call(<String, Object?>{
        'messages': payloadTurns.map((turn) => turn.toJson()).toList(),
      });
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'assistPlannerChat failed: ${error.code} ${error.message}\n$stackTrace',
      );
      throw PlannerAiException(
        aiFunctionsErrorMessage(code: error.code, details: error.details),
      );
    }
    try {
      final raw = result.data;
      if (raw is! Map) throw const FormatException('AI response is not a map');
      final data = Map<String, dynamic>.from(raw);
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
            ? ActiveLanguage.s(
                'Planlamak istediğin şeyi biraz daha anlatır mısın?',
              )
            : message,
        tasks: tasks,
        usage: AiChatUsage.fromJson(data['usage']),
      );
    } catch (error, stackTrace) {
      debugPrint('assistPlannerChat response failed: $error\n$stackTrace');
      throw PlannerAiException(
        ActiveLanguage.s(
          'Plan asistanının yanıtını anlayamadım. Tekrar deneyebilir misin?',
        ),
      );
    }
  }
}

List<PlannerChatTurn> trimConversationForAiRequest(
  List<PlannerChatTurn> conversation,
) {
  final recent = conversation.length <= _maxAiChatTurns
      ? conversation
      : conversation.sublist(conversation.length - _maxAiChatTurns);
  final selected = <PlannerChatTurn>[];
  var usedCharacters = 0;
  for (final turn in recent.reversed) {
    final contentLength = turn.content.runes.length;
    if (selected.isEmpty ||
        usedCharacters + contentLength <= _maxAiInputCharacters) {
      selected.add(turn);
      usedCharacters += contentLength;
    } else {
      break;
    }
  }
  return selected.reversed.toList(growable: false);
}

String aiFunctionsErrorMessage({
  required String code,
  Object? details,
  bool breakdown = false,
}) {
  final reason = details is Map ? details['reason']?.toString() : null;
  final retrySuffix = _retrySuffix(details);
  final protectedMessage = switch (reason) {
    'AI_FREE_CHAT_MONTHLY_LIMIT_REACHED' =>
      ActiveLanguage.s('Bu ayki ücretsiz AI mesaj hakkın bitti.') + retrySuffix,
    'PREMIUM_REQUIRED' => ActiveLanguage.s(
      'Bu AI özelliğini kullanmak için Premium üyelik gerekiyor.',
    ),
    'AI_RATE_LIMIT_MINUTE' =>
      ActiveLanguage.s(
            'Çok hızlı AI isteği gönderdin. Bir dakika bekleyip tekrar dene.',
          ) +
          retrySuffix,
    'AI_RATE_LIMIT_HOURLY' =>
      ActiveLanguage.s('Saatlik AI kullanım sınırına ulaştın.') + retrySuffix,
    'AI_DAILY_LIMIT_REACHED' =>
      ActiveLanguage.s('Günlük AI kullanım sınırına ulaştın.') + retrySuffix,
    'AI_MONTHLY_LIMIT_REACHED' =>
      ActiveLanguage.s('Aylık AI kullanım sınırına ulaştın.') + retrySuffix,
    'AI_INPUT_TOO_LONG' => ActiveLanguage.s(
      'AI isteği en fazla {count} karakter olabilir.',
      {'count': '$_maxAiInputCharacters'},
    ),
    'AI_PROVIDER_TIMEOUT' => ActiveLanguage.s(
      'Plan asistanı yanıt vermek için fazla bekletti. Tekrar deneyebilirsin.',
    ),
    'AI_PROVIDER_QUOTA_EXCEEDED' => ActiveLanguage.s(
      'Plan asistanı şu anda yoğun. Biraz sonra tekrar deneyebilir misin?',
    ),
    'AI_MODEL_UNAVAILABLE' ||
    'AI_CONFIGURATION_UNAVAILABLE' => ActiveLanguage.s(
      'Plan asistanı geçici olarak kullanılamıyor. Biraz sonra tekrar dene.',
    ),
    'AI_PROVIDER_UNAVAILABLE' => ActiveLanguage.s(
      'Plan asistanı şu anda yanıt vermiyor. Biraz sonra tekrar dene.',
    ),
    'AI_MALFORMED_RESPONSE' => ActiveLanguage.s(
      'Plan asistanının yanıtını anlayamadım. Tekrar deneyebilir misin?',
    ),
    _ => null,
  };
  if (protectedMessage != null) return protectedMessage;

  return switch (code) {
    'unauthenticated' => ActiveLanguage.s(
      'Plan asistanı için giriş yapmış olman gerekiyor.',
    ),
    'not-found' => ActiveLanguage.s(
      'Plan asistanı fonksiyonu bulunamadı. Firebase Functions henüz deploy edilmemiş olabilir.',
    ),
    'failed-precondition' => ActiveLanguage.s(
      'Plan asistanı geçici olarak kullanılamıyor. Biraz sonra tekrar dene.',
    ),
    'resource-exhausted' => ActiveLanguage.s(
      'Plan asistanı şu anda yoğun. Biraz sonra tekrar deneyebilir misin?',
    ),
    'unavailable' || 'deadline-exceeded' => ActiveLanguage.s(
      'Plan asistanı şu anda yanıt vermiyor. Biraz sonra tekrar dene.',
    ),
    _ => ActiveLanguage.s(
      breakdown
          ? ActiveLanguage.s(
              'AI alt görevleri şu an oluşturamadı. Tekrar deneyebilirsin.',
            )
          : ActiveLanguage.s(
              'Şu anda plan asistanına bağlanamadım. Biraz sonra tekrar deneyebilir misin?',
            ),
    ),
  };
}

String _retrySuffix(Object? details) {
  if (details is! Map) return '';
  final retryAt = DateTime.tryParse(details['retryAt']?.toString() ?? '');
  if (retryAt == null) return '';
  final local = retryAt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return ' ${ActiveLanguage.s('{hour}:{minute} sonrasında tekrar deneyebilirsin.', {'hour': hour, 'minute': minute})}';
}
