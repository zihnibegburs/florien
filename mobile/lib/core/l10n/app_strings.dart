import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/storage/settings_storage.dart';

const supportedLanguageCodes = ['en', 'tr'];

final appLanguageProvider = AsyncNotifierProvider<AppLanguageNotifier, String>(
  AppLanguageNotifier.new,
);

class AppLanguageNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => ref.read(settingsStorageProvider).getLanguage();

  Future<void> setLanguage(String code) async {
    await ref.read(settingsStorageProvider).setLanguage(code);
    state = AsyncData(code);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ref.read(userProfileServiceProvider).patchSettings(uid, {
          'language': code,
        });
      } catch (_) {}
    }
  }
}

class S {
  const S(this.lang);
  final String lang;

  String _text(String en, String tr) => lang == 'tr' ? tr : en;

  String get loginTagline =>
      _text('A calm place for your tasks', 'Görevlerin için sade bir alan');
  String get email => _text('Email', 'E-posta');
  String get emailRequired => _text('Email is required', 'E-posta gerekli');
  String get password => _text('Password', 'Şifre');
  String get passwordMin6 => _text('At least 6 characters', 'En az 6 karakter');
  String get login => _text('Log in', 'Giriş Yap');
  String get orContinueWith =>
      _text('or continue with', 'veya şununla devam et');
  String get loginWithGoogle =>
      _text('Continue with Google', 'Google ile devam et');
  String get loginWithApple =>
      _text('Continue with Apple', 'Apple ile devam et');
  String get noAccountRegister => _text('Create an account', 'Hesap oluştur');
  String get createAccount => _text('Create account', 'Hesap oluştur');
  String get registerSubtitle => _text(
    'Start keeping your tasks together.',
    'Görevlerini tek yerde toplamaya başla.',
  );
  String get yourName => _text('Your name', 'Adın');
  String get nameMin2 =>
      _text('Enter at least 2 characters', 'En az 2 karakter gir');
  String get validEmail =>
      _text('Enter a valid email', 'Geçerli bir e-posta gir');
  String get register => _text('Register', 'Kayıt ol');

  String get premiumAppBar => _text('Florien Premium', 'Florien Premium');
  String get premiumActive => _text('Premium is active', 'Premium aktif');
  String get premiumActiveDescription => _text(
    'Your account has been upgraded to Premium.',
    'Hesabın Premium olarak etkinleştirildi.',
  );
  String get premiumThanksTitle =>
      _text('Thank you for joining Premium', 'Premium’a katıldığın için teşekkürler');
  String get premiumThanksDescription => _text(
    'Your plan is ready. You can keep planning with every Premium feature unlocked.',
    'Planın hazır. Tüm Premium özelliklerle planlamaya devam edebilirsin.',
  );
  String get premiumIntro => _text(
    'Choose the support that fits the way you plan.',
    'Planlama şekline uygun desteği seç.',
  );
  String get florienFeatures =>
      _text('Florien features', 'Florien özellikleri');
  String get feature => _text('Feature', 'Özellik');
  String get standard => _text('Standard', 'Standart');
  String get premium => _text('Premium', 'Premium');
  String get tasksAndDailyPlan =>
      _text('To-dos and daily plan', 'Yapılacaklar ve günlük plan');
  String get focusTimer => _text('Focus timer', 'Odak zamanlayıcısı');
  String get readyRoutines => _text('Ready-made routines', 'Hazır rutinler');
  String get dailyReflections =>
      _text('Daily reflections', 'Günlük yansımalar');
  String get aiPlanAssistant =>
      _text('AI planning assistant', 'AI plan asistanı');
  String get subtasks => _text('Subtasks', 'Alt görevler');
  String get multipleProfiles =>
      _text('Multiple profiles', 'Birden fazla profil');
  String get calendarImport => _text('Calendar import', 'Takvim aktarma');
  String get reminders =>
      _text('Alarms and reminders', 'Alarm ve hatırlatıcılar');
  String get exactTaskTime =>
      _text('Set a specific task time', 'Görev için özel saat');
  String get choosePlan => _text('Choose your plan', 'Planını seç');
  String get monthly => _text('Monthly', 'Aylık');
  String get monthlyPeriod => _text('Renews every month', 'Her ay yenilenir');
  String get monthlyBadge => _text('Flexible', 'Esnek');
  String get yearly => _text('Yearly', 'Yıllık');
  String get yearlyPeriod => _text('Renews once a year', 'Yılda bir yenilenir');
  String get yearlyBadge => _text('Best value', 'En avantajlı');
  String premiumDailyPrice(String price) =>
      _text('About $price per day', 'Günde yaklaşık $price');
  String get processing => _text('Processing...', 'İşleniyor...');
  String get premiumComingSoon =>
      _text('Premium coming soon', 'Premium yakında');
  String premiumPurchaseCta(String price) =>
      _text('Get Premium for $price', '$price karşılığında Premium ol');
  String get restorePurchases =>
      _text('Restore purchases', 'Satın alımları geri yükle');
  String get continueLabel => _text('Continue', 'Devam et');
  String get skipForNow => _text('Not now', 'Şimdilik geç');
  String get notificationIntroTitle => _text(
    'Let Florien gently remind you',
    'Florien sana nazikçe hatırlatsın',
  );
  String get notificationIntroDescription => _text(
    'Get a reminder when a task starts or a focus session ends.',
    'Bir görevin zamanı geldiğinde veya odak süren bittiğinde haber verelim.',
  );
  String get notificationIntroPrivacy => _text(
    'No unnecessary notifications. You can change this anytime in Settings.',
    'Gereksiz bildirim göndermeyiz. Bunu Ayarlar’dan istediğin zaman değiştirebilirsin.',
  );
  String get allowNotifications =>
      _text('Allow notifications', 'Bildirimlere izin ver');
  String get notificationPermissionError => _text(
    'Notification permission could not be requested. You can try again later in Settings.',
    'Bildirim izni istenemedi. Daha sonra Ayarlar’dan tekrar deneyebilirsin.',
  );
  String get updatesIntroTitle => _text(
    'Would you like to hear from Florien?',
    'Florien’den haberdar olmak ister misin?',
  );
  String get updatesIntroDescription => _text(
    'Be the first to hear about new features, helpful tips and special campaigns.',
    'Yeni özellikleri, faydalı ipuçlarını ve özel kampanyaları ilk sen duy.',
  );
  String get updatesIntroPrivacy => _text(
    'We will only contact you when there is something worthwhile. You can change this preference anytime.',
    'Yalnızca paylaşmaya değer bir şey olduğunda haber veririz. Tercihini istediğin zaman değiştirebilirsin.',
  );
  String get allowUpdates => _text('Yes, keep me updated', 'Evet, haber ver');
  String get declineUpdates => _text('No, thanks', 'Hayır, teşekkürler');
  String get purchaseInfoUnavailable => _text(
    'Purchase information could not be loaded.',
    'Satın alma bilgisi alınamadı.',
  );
  String get storeUnavailable => _text(
    'The store is currently unavailable.',
    'Mağaza şu anda kullanılamıyor.',
  );
  String get premiumProductsNotConfigured => _text(
    'Premium subscriptions have not been configured in the store yet.',
    'Premium abonelikleri mağazada henüz yapılandırılmadı.',
  );
  String get premiumProductsTemporarilyUnavailable => _text(
    'Premium plans could not be loaded from the App Store right now.',
    'Premium planları şu anda App Store’dan yüklenemedi.',
  );
  String get retryStoreProducts =>
      _text('Try loading plans again', 'Planları tekrar yükle');
  String get storePricePending =>
      _text('Waiting for App Store price', 'App Store fiyatı bekleniyor');
  String get premiumInfoUnavailable => _text(
    'Premium information is unavailable.',
    'Premium bilgisi alınamadı.',
  );
  String get premiumProductUnavailable => _text(
    'The Premium product is currently unavailable.',
    'Premium ürünü şu anda satın alınamıyor.',
  );
  String get purchaseCouldNotStart => _text(
    'The purchase could not be started. Please try again.',
    'Satın alma başlatılamadı. Lütfen tekrar dene.',
  );
  String get purchasesCouldNotRestore => _text(
    'Purchases could not be restored.',
    'Satın alımlar geri yüklenemedi.',
  );
  String get premiumCouldNotVerify => _text(
    'Your Premium subscription could not be verified. Please try again.',
    'Premium aboneliğin doğrulanamadı. Tekrar dene.',
  );
  String get purchaseCouldNotComplete => _text(
    'The purchase could not be completed.',
    'Satın alma tamamlanamadı.',
  );
  String get premiumPurchaseAlreadyClaimed => _text(
    'This purchase is linked to another Florien account.',
    'Bu satın alma başka bir Florien hesabına bağlı.',
  );
  String get premiumVerificationUnavailable => _text(
    'Premium verification is currently unavailable. Please try again later.',
    'Premium doğrulaması şu anda kullanılamıyor. Biraz sonra tekrar dene.',
  );
  String get activePremiumCouldNotVerify => _text(
    'The active Premium subscription could not be verified.',
    'Aktif Premium abonelik doğrulanamadı.',
  );
}

final stringsProvider = Provider<S>((ref) {
  return S(ref.watch(appLanguageProvider).valueOrNull ?? 'tr');
});
