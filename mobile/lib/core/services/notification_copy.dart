/// Date-stable notification titles and bodies (no random selection).
class NotificationCopy {
  NotificationCopy._();

  static const morningTitle = 'Bugünün planı';
  static const motivationTitle = 'Küçük bir hatırlatma';
  static const dailyReviewTitle = 'Günü değerlendirelim';
  static const weeklyReviewTitle = 'Haftayı planlayalım';
  static const taskTitle = 'Sıradaki görevin';
  static const batchTitle = 'Sıradaki görevlerin';

  static const morningBodies = [
    'Günaydın. Bugünün planına birlikte bakalım.',
    'Bugün ne var, kısaca gözden geçirelim.',
    'Günün hazır. Sıradaki adımı seçmen yeterli.',
    'Planına bir bak, sonra ilk adımdan başla.',
  ];

  static const motivationBodies = [
    'Her şeyi bir anda yapmak zorunda değilsin.',
    'Küçük bir adım da ilerlemedir.',
    'Plan değiştiyse kaldığın yerden devam edebilirsin.',
    'Şimdi sadece sıradaki işe bak.',
  ];

  static const dailyReviewBodies = [
    'Bugün nasıl geçti, kısaca bakalım.',
    'Neler bitti, neler yarına kalabilir?',
    'Günü kapatmadan kısa bir değerlendirme yapalım.',
    'Bugünden aklında kalanı kaydetmek ister misin?',
  ];

  static const weeklyReviewBodies = [
    'Önümüzdeki haftayı birlikte tasarlayalım.',
    'Bu hafta neleri başarmak istiyoruz?',
    'Yeni hafta başlamadan hedeflerimizi netleştirelim.',
    'Yol haritamızı çizip ilk adımı atalım.',
  ];

  static String pick(List<String> options, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final index = day.difference(DateTime.utc(2020, 1, 1)).inDays.abs();
    return options[index % options.length];
  }

  static String taskBody({
    required String taskTitle,
    required int leadMinutes,
  }) {
    if (leadMinutes <= 0) {
      return '$taskTitle şimdi başlıyor.';
    }
    return '$taskTitle · $leadMinutes dk kaldı.';
  }

  static String batchBody(List<String> titles) {
    final count = titles.length;
    final preview = titles.take(3).join(', ');
    if (count <= 3) {
      return '$count görev: $preview';
    }
    return '$count görev: $preview ve ${count - 3} tane daha';
  }
}
