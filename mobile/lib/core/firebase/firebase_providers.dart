import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Firebase-backed caches remain optional in unit/widget tests and before
/// Firebase initialization. Production iOS resolves these to live instances.
final optionalFirestoreProvider = Provider<FirebaseFirestore?>((ref) {
  try {
    return ref.watch(firestoreProvider);
  } catch (_) {
    return null;
  }
});

final optionalFirebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  try {
    return ref.watch(firebaseAuthProvider);
  } catch (_) {
    return null;
  }
});

final cloudFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: 'us-central1'),
);

/// `users/{uid}`
DocumentReference<Map<String, dynamic>> userDoc(
  FirebaseFirestore db,
  String uid,
) => db.collection('users').doc(uid);

/// `users/{uid}/tasks` for the legacy primary profile, otherwise
/// `users/{uid}/profiles/{profileId}/tasks`.
CollectionReference<Map<String, dynamic>> tasksCol(
  FirebaseFirestore db,
  String uid,
  String profileId,
) {
  final user = userDoc(db, uid);
  if (profileId == 'primary') return user.collection('tasks');
  return user.collection('profiles').doc(profileId).collection('tasks');
}
