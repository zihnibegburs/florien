import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:florien/core/models/mood_entry.dart';

class AppleHealthMoodSample {
  const AppleHealthMoodSample({required this.date, required this.mood});

  final DateTime date;
  final MoodLevel mood;
}

class AppleHealthMoodService {
  static const _channel = MethodChannel('florien/health_mood');

  bool get isSupported => defaultTargetPlatform == TargetPlatform.iOS;

  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isSharingAuthorized() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isSharingAuthorized') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> save(MoodEntry entry) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('saveDailyMood', {
            'timestamp': entry.day.millisecondsSinceEpoch,
            'valence': entry.mood.valence,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<AppleHealthMoodSample>> readWeek(DateTime weekStart) async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'readDailyMoods',
        {'start': weekStart.millisecondsSinceEpoch},
      );
      return (raw ?? const [])
          .map((item) {
            final timestamp = item['timestamp'] as num?;
            final valence = item['valence'] as num?;
            if (timestamp == null || valence == null) return null;
            return AppleHealthMoodSample(
              date: DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()),
              mood: MoodLevelDetails.fromValence(valence.toDouble()),
            );
          })
          .whereType<AppleHealthMoodSample>()
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
