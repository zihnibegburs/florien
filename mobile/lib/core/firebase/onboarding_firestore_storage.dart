import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/storage/onboarding_storage.dart';

class OnboardingFirestoreStorage implements OnboardingRemoteStorage {
  OnboardingFirestoreStorage(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _surveyDoc(String userId) => userDoc(
    _db,
    userId,
  ).collection('onboarding_surveys').doc(currentOnboardingVersion);

  @override
  Future<OnboardingPreferences> load(String userId) async {
    final snapshot = await _surveyDoc(userId).get();
    final data = snapshot.data();
    if (data == null) return const OnboardingPreferences();
    return OnboardingPreferences.fromJson(data);
  }

  @override
  Future<void> save(String userId, OnboardingPreferences preferences) =>
      _surveyDoc(userId).set({
        ...preferences.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
