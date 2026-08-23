import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/l10n/app_language.dart';
import 'package:florien/core/l10n/catalog.dart';
import 'package:florien/core/storage/settings_storage.dart';

export 'package:florien/core/l10n/app_language.dart';

class ActiveLanguage {
  static String code = defaultLanguageCode;

  static S get s => S(code);
}

final appLanguageProvider = AsyncNotifierProvider<AppLanguageNotifier, String>(
  AppLanguageNotifier.new,
);

class AppLanguageNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final saved = await ref.read(settingsStorageProvider).getSavedLanguage();
    final resolved = resolveAppLanguage(
      savedOverride: saved,
      deviceLocale: deviceLocale(),
    );
    ActiveLanguage.code = resolved;
    return resolved;
  }

  Future<void> setLanguage(String? code) async {
    final normalized = normalizeLanguageCode(code);
    await ref.read(settingsStorageProvider).setLanguage(normalized);
    final resolved = resolveAppLanguage(
      savedOverride: normalized,
      deviceLocale: deviceLocale(),
    );
    ActiveLanguage.code = resolved;
    state = AsyncData(resolved);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(userProfileServiceProvider).patchSettings(uid, {
        'language': resolved,
      });
    } catch (_) {}
  }
}

class S {
  const S(this.lang);
  final String lang;

  String call(String source, [Map<String, String> params = const {}]) {
    return lookupTranslation(lang, source, params);
  }

  static S of(BuildContext context) {
    try {
      return ProviderScope.containerOf(context).read(stringsProvider);
    } catch (_) {
      return ActiveLanguage.s;
    }
  }

  String get loginTagline => this('Görevlerin için sade bir alan');
  String get email => this('E-posta');
  String get emailRequired => this('E-posta gerekli');
  String get password => this('Şifre');
  String get passwordMin6 => this('En az 6 karakter');
  String get login => this('Giriş Yap');
  String get orContinueWith => this('veya şununla devam et');
  String get loginWithGoogle => this('Google ile devam et');
  String get loginWithApple => this('Apple ile devam et');
  String get noAccountRegister => this('Hesap oluştur');
  String get createAccount => this('Hesap oluştur');
  String get registerSubtitle => this('Görevlerini tek yerde toplamaya başla.');
  String get yourName => this('Adın');
  String get nameMin2 => this('En az 2 karakter gir');
  String get validEmail => this('Geçerli bir e-posta gir');
  String get register => this('Kayıt ol');

  String get premiumAppBar => this('Florien Premium');
  String get premiumActive => this('Premium aktif');
  String get premiumActiveDescription =>
      this('Hesabın Premium olarak etkinleştirildi.');
  String get premiumThanksTitle =>
      this('Premium’a katıldığın için teşekkürler');
  String get premiumThanksDescription => this(
    'Planın hazır. Tüm Premium özelliklerle planlamaya devam edebilirsin.',
  );
  String get premiumIntro => this('Planlama şekline uygun desteği seç.');
  String get florienFeatures => this('Florien özellikleri');
  String get feature => this('Özellik');
  String get standard => this('Standart');
  String get premium => this('Premium');
  String get tasksAndDailyPlan => this('Yapılacaklar ve günlük plan');
  String get focusTimer => this('Odak zamanlayıcısı');
  String get readyRoutines => this('Hazır rutinler');
  String get dailyReflections => this('Günlük yansımalar');
  String get aiPlanAssistant => this('AI plan asistanı');
  String get subtasks => this('Alt görevler');
  String get multipleProfiles => this('Birden fazla profil');
  String get calendarImport => this('Takvim aktarma');
  String get reminders => this('Alarm ve hatırlatıcılar');
  String get exactTaskTime => this('Görev için özel saat');
  String get choosePlan => this('Planını seç');
  String get monthly => this('Aylık');
  String get monthlyPeriod => this('Her ay yenilenir');
  String get monthlyBadge => this('Esnek');
  String get yearly => this('Yıllık');
  String get yearlyPeriod => this('Yılda bir yenilenir');
  String get yearlyBadge => this('En avantajlı');
  String premiumDailyPrice(String price) =>
      this('Günde yaklaşık {price}', {'price': price});
  String get processing => this('İşleniyor...');
  String get premiumComingSoon => this('Premium yakında');
  String premiumPurchaseCta(String price) =>
      this('{price} karşılığında Premium ol', {'price': price});
  String get restorePurchases => this('Satın alımları geri yükle');
  String get continueLabel => this('Devam et');
  String get skipForNow => this('Şimdilik geç');
  String get notificationIntroTitle => this('Florien sana nazikçe hatırlatsın');
  String get notificationIntroDescription => this(
    'Bir görevin zamanı geldiğinde veya odak süren bittiğinde haber verelim.',
  );
  String get notificationIntroPrivacy => this(
    'Gereksiz bildirim göndermeyiz. Bunu Ayarlar’dan istediğin zaman değiştirebilirsin.',
  );
  String get allowNotifications => this('Bildirimlere izin ver');
  String get notificationPermissionError => this(
    'Bildirim izni istenemedi. Daha sonra Ayarlar’dan tekrar deneyebilirsin.',
  );
  String get updatesIntroTitle =>
      this('Florien’den haberdar olmak ister misin?');
  String get updatesIntroDescription => this(
    'Yeni özellikleri, faydalı ipuçlarını ve özel kampanyaları ilk sen duy.',
  );
  String get updatesIntroPrivacy => this(
    'Yalnızca paylaşmaya değer bir şey olduğunda haber veririz. Tercihini istediğin zaman değiştirebilirsin.',
  );
  String get allowUpdates => this('Evet, haber ver');
  String get declineUpdates => this('Hayır, teşekkürler');
  String get purchaseInfoUnavailable => this('Satın alma bilgisi alınamadı.');
  String get storeUnavailable => this('Mağaza şu anda kullanılamıyor.');
  String get premiumProductsNotConfigured =>
      this('Premium abonelikleri mağazada henüz yapılandırılmadı.');
  String get premiumProductsTemporarilyUnavailable =>
      this('Premium planları şu anda App Store’dan yüklenemedi.');
  String get retryStoreProducts => this('Planları tekrar yükle');
  String get storePricePending => this('App Store fiyatı bekleniyor');
  String get premiumInfoUnavailable => this('Premium bilgisi alınamadı.');
  String get premiumProductUnavailable =>
      this('Premium ürünü şu anda satın alınamıyor.');
  String get purchaseCouldNotStart =>
      this('Satın alma başlatılamadı. Lütfen tekrar dene.');
  String get purchasesCouldNotRestore =>
      this('Satın alımlar geri yüklenemedi.');
  String get premiumCouldNotVerify =>
      this('Premium aboneliğin doğrulanamadı. Tekrar dene.');
  String get purchaseCouldNotComplete => this('Satın alma tamamlanamadı.');
  String get premiumPurchaseAlreadyClaimed =>
      this('Bu satın alma başka bir Florien hesabına bağlı.');
  String get premiumVerificationUnavailable => this(
    'Premium doğrulaması şu anda kullanılamıyor. Biraz sonra tekrar dene.',
  );
  String get activePremiumCouldNotVerify =>
      this('Aktif Premium abonelik doğrulanamadı.');
}

final stringsProvider = Provider<S>((ref) {
  return S(ref.watch(appLanguageProvider).valueOrNull ?? ActiveLanguage.code);
});

extension FlorienL10nContext on BuildContext {
  S get s => S.of(this);

  String l10n(String source, [Map<String, String> params = const {}]) {
    return S.of(this)(source, params);
  }
}
