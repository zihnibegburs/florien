import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:florien/core/l10n/app_strings.dart';

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
    if (uid == null)
      throw StateError(
        ActiveLanguage.s('Geri bildirim için giriş yapmalısın.'),
      );
    final normalizedIssue = issue.trim();
    final normalizedSuggestion = suggestion.trim();
    if (rating < 1 || rating > 3) {
      throw ArgumentError.value(rating, 'rating');
    }
    if (normalizedIssue.isEmpty && normalizedSuggestion.isEmpty) {
      throw StateError(ActiveLanguage.s('Lütfen sorununu veya önerini yaz.'));
    }
    if (normalizedIssue.runes.length > reviewFeedbackMaxCharacters ||
        normalizedSuggestion.runes.length > reviewFeedbackMaxCharacters) {
      throw StateError(
        ActiveLanguage.s(
          'Her geri bildirim alanı en fazla {count} karakter olabilir.',
          {'count': '$reviewFeedbackMaxCharacters'},
        ),
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
