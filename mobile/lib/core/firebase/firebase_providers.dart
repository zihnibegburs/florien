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

final cloudFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: 'us-central1'),
);

/// `users/{uid}`
DocumentReference<Map<String, dynamic>> userDoc(
  FirebaseFirestore db,
  String uid,
) => db.collection('users').doc(uid);

/// `users/{uid}/tasks`
CollectionReference<Map<String, dynamic>> tasksCol(
  FirebaseFirestore db,
  String uid,
) => userDoc(db, uid).collection('tasks');
