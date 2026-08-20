import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementProgressStorage {
  AchievementProgressStorage({FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const _completedPrefix = 'achievement_completed_high_water_v1_';
  static const _celebratedPrefix = 'achievement_celebrated_threshold_v1_';

  final FirebaseFirestore? _firestore;

  Future<int> preserveCompletedTaskCount({
    required String profileScope,
    required int currentCount,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_completedPrefix$profileScope';
    final previous = preferences.getInt(key) ?? 0;
    final remote = await _loadRemote(profileScope);
    final remoteCount = remote?['completedTaskCount'];
    final storedRemoteCount = remoteCount is num ? remoteCount.toInt() : 0;
    final highest = [
      currentCount,
      previous,
      storedRemoteCount,
    ].reduce((first, second) => first > second ? first : second);
    if (highest != previous) await preferences.setInt(key, highest);
    await _saveRemote(profileScope, {'completedTaskCount': highest});
    return highest;
  }

  Future<int> loadCelebratedThreshold(String profileScope) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_celebratedPrefix$profileScope';
    final local = preferences.getInt(key) ?? 0;
    final remote = await _loadRemote(profileScope);
    final remoteValue = remote?['celebratedThreshold'];
    final storedRemote = remoteValue is num ? remoteValue.toInt() : 0;
    final highest = local > storedRemote ? local : storedRemote;
    if (highest != local) await preferences.setInt(key, highest);
    if (highest != storedRemote) {
      await _saveRemote(profileScope, {'celebratedThreshold': highest});
    }
    return highest;
  }

  Future<void> markCelebrated({
    required String profileScope,
    required int threshold,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_celebratedPrefix$profileScope';
    final previous = preferences.getInt(key) ?? 0;
    final next = threshold > previous ? threshold : previous;
    if (next != previous) await preferences.setInt(key, next);
    await _saveRemote(profileScope, {'celebratedThreshold': next});
  }

  DocumentReference<Map<String, dynamic>>? _remoteRef(String profileScope) {
    final firestore = _firestore;
    final separator = profileScope.indexOf(':');
    if (firestore == null || separator <= 0) return null;
    final userId = profileScope.substring(0, separator);
    final profileId = profileScope.substring(separator + 1);
    if (userId == 'guest' || profileId.isEmpty) return null;
    return firestore
        .collection('users')
        .doc(userId)
        .collection('profiles')
        .doc(profileId)
        .collection('app_data')
        .doc('achievement_progress');
  }

  Future<Map<String, dynamic>?> _loadRemote(String profileScope) async {
    final ref = _remoteRef(profileScope);
    if (ref == null) return null;
    try {
      return (await ref.get()).data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRemote(String profileScope, Map<String, int> values) async {
    final ref = _remoteRef(profileScope);
    if (ref == null) return;
    try {
      await ref.set({
        ...values,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
