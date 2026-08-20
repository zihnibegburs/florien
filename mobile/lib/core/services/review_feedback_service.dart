import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const reviewFeedbackMaxCharacters = 500;

class ReviewFeedbackService {
  ReviewFeedbackService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> submit({
    required int rating,
    required String issue,
    required String suggestion,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Geri bildirim için giriş yapmalısın.');
    final normalizedIssue = issue.trim();
    final normalizedSuggestion = suggestion.trim();
    if (rating < 1 || rating > 3) {
      throw ArgumentError.value(rating, 'rating');
    }
    if (normalizedIssue.isEmpty && normalizedSuggestion.isEmpty) {
      throw StateError('Lütfen sorununu veya önerini yaz.');
    }
    if (normalizedIssue.runes.length > reviewFeedbackMaxCharacters ||
        normalizedSuggestion.runes.length > reviewFeedbackMaxCharacters) {
      throw StateError(
        'Her geri bildirim alanı en fazla $reviewFeedbackMaxCharacters karakter olabilir.',
      );
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('review_feedback')
        .add({
          'rating': rating,
          'issue': normalizedIssue,
          'suggestion': normalizedSuggestion,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
