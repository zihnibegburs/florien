import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/models/ai_models.dart';
import 'package:florien/firebase_options.dart';

class AiRepository {
  AiRepository(this._functions);

  final FirebaseFunctions _functions;

  void _ensureConfigured() {
    if (!DefaultFirebaseOptions.isConfigured) {
      throw StateError(
        'Firebase henüz yapılandırılmadı. mobile/lib/firebase_options.dart '
        'dosyasını flutterfire configure ile doldur.',
      );
    }
  }

  /// Cloud Functions returns nested `Map<Object?, Object?>` on mobile — deep-convert.
  static dynamic normalize(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) e.key.toString(): normalize(e.value),
      };
    }
    if (value is List) {
      return value.map(normalize).toList();
    }
    return value;
  }

  static Map<String, dynamic> asStringKeyMap(dynamic data) {
    final normalized = normalize(data);
    if (normalized is Map<String, dynamic>) return normalized;
    throw StateError('Unexpected Cloud Function response: ${data.runtimeType}');
  }

  Future<AiBreakdownModel> breakdown(String task) async {
    _ensureConfigured();
    final callable = _functions.httpsCallable('assistBreakdown');
    final result = await callable.call({'task': task});
    return AiBreakdownModel.fromJson(asStringKeyMap(result.data));
  }

  Future<AiPlanModel> plan(String input, {DateTime? date}) async {
    _ensureConfigured();
    final dateStr = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : null;
    final callable = _functions.httpsCallable('assistPlan');
    final result = await callable.call({
      'input': input,
      if (dateStr != null) 'date': dateStr,
    });
    return AiPlanModel.fromJson(asStringKeyMap(result.data));
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(cloudFunctionsProvider));
});
