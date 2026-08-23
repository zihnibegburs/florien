import 'package:florien/core/l10n/app_strings.dart';

/// Date-stable notification titles and bodies (no random selection).
class NotificationCopy {
  NotificationCopy._();

  static S get _s => ActiveLanguage.s;

  static String get morningTitle => _s('Bugünün planı');
  static String get motivationTitle => _s('Küçük bir hatırlatma');
  static String get dailyReviewTitle => _s('Günü değerlendirelim');
  static String get weeklyReviewTitle => _s('Haftayı planlayalım');
  static String get taskTitle => _s('Sıradaki görevin');
  static String get batchTitle => _s('Sıradaki görevlerin');

  static List<String> get morningBodies => [
    _s('Günaydın. Bugünün planına birlikte bakalım.'),
    _s('Bugün ne var, kısaca gözden geçirelim.'),
    _s('Günün hazır. Sıradaki adımı seçmen yeterli.'),
    _s('Planına bir bak, sonra ilk adımdan başla.'),
  ];

  static List<String> get motivationBodies => [
    _s('Her şeyi bir anda yapmak zorunda değilsin.'),
    _s('Küçük bir adım da ilerlemedir.'),
    _s('Plan değiştiyse kaldığın yerden devam edebilirsin.'),
    _s('Şimdi sadece sıradaki işe bak.'),
  ];

  static List<String> get dailyReviewBodies => [
    _s('Bugün nasıl geçti, kısaca bakalım.'),
    _s('Neler bitti, neler yarına kalabilir?'),
    _s('Günü kapatmadan kısa bir değerlendirme yapalım.'),
    _s('Bugünden aklında kalanı kaydetmek ister misin?'),
  ];

  static List<String> get weeklyReviewBodies => [
    _s('Önümüzdeki haftayı birlikte tasarlayalım.'),
    _s('Bu hafta neleri başarmak istiyoruz?'),
    _s('Yeni hafta başlamadan hedeflerimizi netleştirelim.'),
    _s('Yol haritamızı çizip ilk adımı atalım.'),
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
      return _s('{title} şimdi başlıyor.', {'title': taskTitle});
    }
    return _s('{title} · {minutes} dk kaldı.', {
      'title': taskTitle,
      'minutes': '$leadMinutes',
    });
  }

  static String batchBody(List<String> titles) {
    final count = titles.length;
    final preview = titles.take(3).join(', ');
    if (count <= 3) {
      return _s('{count} görev: {preview}', {
        'count': '$count',
        'preview': preview,
      });
    }
    return _s('{count} görev: {preview} ve {more} tane daha', {
      'count': '$count',
      'preview': preview,
      'more': '${count - 3}',
    });
  }
}
