# Florien — iOS yayınlama rehberi

Bu belge, uygulamanın **gerçekten App Store’da yayınlanması** için gereken her şeyi sırayla anlatır. Android henüz kapsam dışı. Hedef: Firebase production + iOS 1.0.0.

Kod tarafı büyük ölçüde hazır. Yayın işinin çoğu Apple, Google Cloud, yasal metinler ve mağaza listesinde.

---

## 0. Şu anki durum

| Parça | Değer |
| --- | --- |
| Uygulama adı | Florien |
| Bundle ID | `com.florien.app` |
| Widget bundle ID | `com.florien.app.FlorienWidget` |
| App Group | `group.com.florien.app` |
| Apple Team ID | `65V5D6DTQ2` |
| App Store ID (kodda) | `6799938907` |
| Sürüm | `1.0.0+3` (`pubspec.yaml`) |
| Minimum iOS | 16.1 |
| Cihaz | iPhone + iPad (universal) |
| Firebase proje | `florien-74ad8` |
| Functions bölge | `us-central1` (varsayılan) |
| Sağlayıcı | Alperen Demirdöğer / Wire & Fire |
| Destek | `support@wirefire.co` |
| Gizlilik | https://www.wirefire.co/florien/privacy |
| Şartlar | https://www.wirefire.co/florien/terms |
| Hesap silme | https://www.wirefire.co/florien/delete-account |
| Yaş | Hesap için 16+ |
| Aylık abonelik | `com.florien.app.subscription.monthly` |
| Yıllık abonelik | `com.florien.app.subscription.yearly` |
| Apple S2S bildirim URL | `https://us-central1-florien-74ad8.cloudfunctions.net/appleServerNotifications` |

Kodda hazır olanlar:

- Sign in with Apple, Google, e-posta
- Ayarlarda hesap silme (`deleteAccount` Cloud Function)
- Premium satın alma + geri yükleme
- App Store Server Notifications V2 endpoint
- Widget + Live Activities
- TestFlight Fastlane + GitHub Actions
- 1024×1024 App Store ikonu
- TR/EN ve diğer diller için izin metinleri (`InfoPlist.strings`)

Kodda / süreçte kapanması gerekenler:

- Privacy manifest eklendi (`Runner` + widget); `ITSAppUsesNonExemptEncryption` hâlâ yok
- `ITSAppUsesNonExemptEncryption` Info.plist’te yok (yüklemede soru çıkar)
- Fastlane şu an yalnızca TestFlight’a yükler; mağaza sürümünü App Store Connect’ten elle yayınlarsın
- Android / web `firebase_options` hâlâ placeholder; iOS yayınını etkilemez

---

## 1. Yayın sırası (önerilen)

İşleri bu sırayla bitir. Paralel gidebilecek adımlar belirtilir.

```
1. Apple sözleşmeleri + vergi/banka
2. Firebase Blaze + production deploy
3. Developer / App ID / capability’ler
4. App Store Connect uygulaması + abonelikler
5. IAP secret + Apple S2S bildirimleri
6. Auth (Apple + Google) production ayarı
7. TestFlight build
8. Sandbox satın alma testi
9. Mağaza listesi + gizlilik etiketleri
10. App Review’a gönder
11. Onay sonrası release
12. İlk 48 saat izleme
```

Toplam süre (belgeler ve sözleşmeler hazırsa): 2–5 gün hazırlık + Apple incelemesi 1–7 gün.

---

## 2. Apple Developer ve sözleşmeler

App Store Connect olmadan IPA yüklesen bile **satışa açılamaz**.

### 2.1 Hesap

1. [Apple Developer](https://developer.apple.com/account) yıllık üyeliğin aktif olsun (`65V5D6DTQ2`).
2. [App Store Connect](https://appstoreconnect.apple.com) → **Business / Agreements, Tax, and Banking**.
3. **Paid Applications Agreement**’ı imzala. Abonelik satacaksan bu zorunlu.
4. **Bankacılık** ve **vergi** formlarını tamamla (Türkiye). Eksikse uygulama “Waiting for Review”a bile gitmeyebilir veya satın alma çalışmaz.
5. İletişim e-postası: `support@wirefire.co`.

### 2.2 App Store Connect API anahtarı

TestFlight / Fastlane için:

1. App Store Connect → **Users and Access** → **Integrations** → **Keys**.
2. **App Manager** yetkili bir API Key üret.
3. `.p8` dosyasını indir (bir kez iner).
4. `Key ID` ve `Issuer ID`’yi sakla.
5. Dosyayı şuraya koy:

```
~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
```

Bu değerler `mobile/ios/fastlane/.env` ve GitHub secrets’a gidecek. `.p8` ve `.p12` **asla git’e girmez**.

### 2.3 Dağıtım sertifikası ve profiller

Gerekli kimlikler:

| Tür | Identifier |
| --- | --- |
| App ID | `com.florien.app` |
| App ID (widget) | `com.florien.app.FlorienWidget` |
| App Group | `group.com.florien.app` |

Ana App ID’de açık olması gereken capability’ler:

- App Groups (`group.com.florien.app`)
- Sign in with Apple
- HealthKit
- Time Sensitive Notifications
- Push Notifications (Time Sensitive için Developer portalında genelde gerekir; uzaktan FCM kullanmasan da)
- Associated Domains — şu an kodda yok, açma

Widget App ID:

- App Groups (`group.com.florien.app`)
- (Live Activities widget extension’da zaten var)

Sonra:

1. **Apple Distribution** sertifikası oluştur, private key ile `.p12` olarak dışa aktar.
2. Her App ID için **App Store** provisioning profile oluştur.
3. App Store Connect’te `com.florien.app` uygulamasının var olduğunu doğrula (koddaki ID: `6799938907`).

Ayrıntılı Fastlane/GitHub adımları: `mobile/ios/TESTFLIGHT_SETUP.md`.

---

## 3. Firebase’i production’a kilitle

Cloud Functions ücretsiz Spark planında **çalışmaz**. Yayın için Blaze (pay-as-you-go) şart.

### 3.1 Proje ve faturalama

1. [Firebase Console](https://console.firebase.google.com/project/florien-74ad8) → **Upgrade to Blaze**.
2. [Google Cloud Billing](https://console.cloud.google.com/billing) içinde **bütçe uyarısı** kur (ör. 10 / 25 / 50 USD). AI ve Functions maliyeti buradan gelir.
3. Şu API’lerin etkin olduğundan emin ol:
   - Cloud Functions
   - Cloud Firestore
   - Identity Toolkit (Auth)
   - Secret Manager
   - Cloud Build
   - Generative Language API (Gemini; kod `GEMINI_API_KEY` kullanıyor)

README’deki Vertex AI notu güncel kodla örtüşmüyor. Production’da **Google AI Studio API key** + Secret Manager kullanılır.

### 3.2 Authentication

Firebase Console → **Authentication** → **Sign-in method**:

| Sağlayıcı | Durum |
| --- | --- |
| E-posta / şifre | Açık |
| Google | Açık; iOS client `com.florien.app` ile eşleşmeli |
| Apple | Açık |

**Apple sağlayıcısı** için Firebase’e girilecekler:

- Services ID (iOS native Sign in with Apple için çoğu kurulumda bundle ID yeter; Firebase web/Android ekleyince ayrı Services ID gerekir)
- Apple Team ID: `65V5D6DTQ2`
- Key ID + `.p8` (Apple’dan “Sign in with Apple” key)

**Authorized domains** listesinde şunlar olsun:

- `florien-74ad8.firebaseapp.com`
- `florien-74ad8.web.app`
- ileride kendi domain’in (`wirefire.co`)

Google Sign-In:

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=florien-74ad8) → OAuth 2.0 Client.
2. iOS client’ın bundle ID’si `com.florien.app` olsun.
3. `Info.plist` içindeki reversed client ID zaten şu:

```
com.googleusercontent.apps.293921233420-anm1urgeau6o5sdfksnbnuto8n6io35g
```

OAuth consent screen’de uygulama adı **Florien**, destek e-postası `support@wirefire.co`, gizlilik URL’si yukarıdaki privacy sayfası olsun.

### 3.3 Firestore kuralları, indexler, config belgeleri

Repo kökünden:

```bash
firebase use production
firebase deploy --only firestore:rules,firestore:indexes
```

Sonra Firestore’da şu belgelerin olduğundan emin ol (yoksa oluştur):

**`appConfig/aiLimits`** — ayrıntı: `docs/ai-limits-config.md`

```bash
cd functions && npm run seed:ai-limits
```

**`appConfig/premiumPaywall`** — ayrıntı: `docs/premium-paywall-config.md`

Bu belgeler istemciden yalnızca okunur; yazma Admin / Console ile yapılır.

### 3.4 Cloud Functions ve secret’lar

```bash
cd functions && npm install && npm run build

firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set APPLE_IAP_CREDENTIALS

firebase deploy --only functions
```

`APPLE_IAP_CREDENTIALS` JSON şeması:

```json
{
  "sharedSecret": "App Store Connect → Subscriptions → App-Specific Shared Secret",
  "issuerId": "App Store Connect issuer UUID",
  "keyId": "In-App Purchase key id (10 karakter)",
  "privateKey": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----"
}
```

`privateKey`, App Store Connect → **Users and Access** → **Integrations** → **In-App Purchase** anahtarının `.p8` içeriğidir. Auth API key’inden **farklı** bir anahtar olabilir.

Deploy sonrası Console’da şunların yeşil olduğunu kontrol et:

- `deleteAccount`
- `verifyPremiumPurchase`
- `registerAppleAppAccountToken`
- `appleServerNotifications` (public HTTPS)
- `getPremiumStatus`
- `assistBreakdown`
- `assistPlan`
- `assistPlannerChat`

`appleServerNotifications` **unauthenticated** (public) olmalı; Apple imzalı payload gönderir. Callable’lar auth ister.

### 3.5 Firebase güvenlik (yayın öncesi önerilir)

- **App Check**: DeviceCheck + App Attest (iOS). Auth / Firestore / Functions’a bağla. İlk hafta monitor mode, sonra enforce.
- Firestore **backup** (günlük).
- IAM: Functions runtime service account’una gereksiz Owner verme.
- Production’da emülatör / debug logging kapat.

---

## 4. App Store Connect — uygulama kaydı

1. App Store Connect → **My Apps** → Florien (`com.florien.app`).
2. Platform: iOS.
3. Bundle ID, Team, SKU sabittir; SKU’yu sonradan değiştirme.
4. Primary language: **English** önerilir (uluslararası mağaza). TR lokalizasyonu ayrıca eklenir.
5. Kategori:
   - Primary: **Productivity**
   - Secondary: **Lifestyle** (Health & Fitness / Medical **seçme**; uygulama tıbbi değil)
6. Content Rights: kendi içeriğin / lisanslı asset’ler.
7. Age: gizlilik metni **16+**. App Store yaş derecelendirmesini buna göre doldur; “Made for Kids” **hayır**.

### 4.1 Mağaza bilgisi URL’leri

App Information ve her lokalizasyonda:

| Alan | Değer |
| --- | --- |
| Privacy Policy URL | `https://www.wirefire.co/florien/privacy` |
| License / EULA | Custom: `https://www.wirefire.co/florien/terms` (Apple standart EULA da olur; sende özel şart var, custom kullan) |
| Support URL | `https://www.wirefire.co/florien` veya destek sayfan |
| Marketing URL | Opsiyonel; site hazırsa ekle |

Uygulama içi Ayarlar zaten terms + privacy’ye gidiyor. Apple, özellikle **abonelik** için privacy URL’sini zorunlu tutar.

### 4.2 App Review iletişim

- Ad / soyad
- Telefon (ülke koduyla)
- E-posta: `support@wirefire.co`
- Demo hesap: e-posta + şifre (aşağıda 8. bölüm)

---

## 5. Abonelikler (IAP)

Dijital Premium özellik satıldığı için **yalnızca** App Store IAP kullanılır. Kod zaten `in_app_purchase` + sunucu doğrulaması yapıyor.

### 5.1 Ürünleri oluştur

App Store Connect → Florien → **Subscriptions**:

1. Bir **Subscription Group** oluştur (ör. `Florien Premium`).
2. İki ürün ekle; Product ID’ler koddakiyle **birebir** aynı olsun:

| Product ID | Referans adı | Süre |
| --- | --- | --- |
| `com.florien.app.subscription.monthly` | Florien Premium Monthly | 1 ay |
| `com.florien.app.subscription.yearly` | Florien Premium Yearly | 1 yıl |

3. Her ürün için:
   - Fiyat (ülke bazlı; Türkiye + ABD mutlaka)
   - Yerelleştirilmiş görünen ad + açıklama (en az EN + TR)
   - Review screenshot (paywall ekranı)
   - Review notu: “Premium unlocks AI add-to-todo, subtasks, extra profiles, calendar import, alarms, custom task times.”

4. Durum **Ready to Submit** olmalı. İlk IAP, uygulama sürümüyle birlikte incelenir.

Ücretsiz deneme vereceksen (ör. 7 gün) burada tanımlarsın. Kod mağaza fiyatını kullanır; tutarı Firestore’dan değiştirme.

### 5.2 StoreKit / sunucu tarafı

1. **App-Specific Shared Secret** üret (Subscriptions sayfası) → `APPLE_IAP_CREDENTIALS.sharedSecret`.
2. **In-App Purchase key** (`.p8`) → `keyId` + `privateKey`.
3. App Information → **App Store Server Notifications**:
   - Production URL: `https://us-central1-florien-74ad8.cloudfunctions.net/appleServerNotifications`
   - Sandbox URL: aynı (tek fonksiyon hem sandbox hem production JWS doğrular)
   - Version: **V2**
4. Console’dan **Send Test Notification** ile 200 OK geldiğini doğrula.

### 5.3 Sandbox test kullanıcıları

App Store Connect → **Users and Access** → **Sandbox** → test Apple ID.

Fiziksel iPhone’da:

1. Ayarlar → App Store → Sandbox Account.
2. TestFlight veya Xcode debug build ile aylık/yıllık satın al.
3. Restore çalışsın.
4. Firebase’de `users/{uid}/private/aiAccess` altında `premiumUntil` dolsun.
5. İptal / süre bitince entitlement düşsün (S2S veya bir sonraki `getPremiumStatus`).

Simulator’da gerçek StoreKit production akışı güvenilir değildir. Mutlaka cihaz.

---

## 6. Xcode / Info.plist yayın öncesi düzeltmeler

Build almadan şunları kapat.

### 6.1 Privacy manifest

Hazır. Her binary kendi dosyasını taşır:

- `mobile/ios/Runner/PrivacyInfo.xcprivacy` — uygulama
- `mobile/ios/FlorienWidget/PrivacyInfo.xcprivacy` — widget

Tracking kapalı. App Store Connect’teki App Privacy etiketlerini bu dosyayla aynı tut.

### 6.2 Export compliance

`Info.plist` içine ekle (yalnızca HTTPS kullanıyorsan, özel kriptografi yoksa):

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Böylece her yüklemede “Export Compliance” sorusu kalkar.

### 6.3 Widget görünen adı

Widget extension `CFBundleDisplayName` şu an `FlorienWidget`. Kullanıcı ana ekranda bunu görür. Mümkünse `Florien` yap.

### 6.4 Sürüm numarası

- `CFBundleShortVersionString` = `1.0.0` (kullanıcının gördüğü)
- `CFBundleVersion` = Fastlane’in artırdığı build (`+3` şu an yerel; TestFlight’ta otomatik artar)

Aynı `1.0.0` ile yeni binary göndermek için yalnızca build numarasını artır.

### 6.5 İkon

`Icon-App-1024x1024@1x.png` şeffaf veya yuvarlatılmış köşeli **olmasın**. Apple reddeder. Düz kare, kenarlarda alfa yok.

---

## 7. TestFlight build

İki yol var. İkisi de aynı Fastlane `beta` lane’ini kullanır.

### 7.1 Yerel

```bash
cd mobile/ios
bundle install
bundle exec pod install
cp fastlane/.env.example fastlane/.env
# .env doldur
bundle exec fastlane beta
```

### 7.2 GitHub Actions

Secrets (hepsi zorunlu):

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY` (`.p8` base64)
- `IOS_DIST_CERTIFICATE_BASE64`
- `IOS_DIST_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`

```bash
gh workflow run mobile-ios.yml -f deploy_testflight=true
```

Build işlenince (10–30 dk) App Store Connect → TestFlight.

### 7.3 Dahili / harici test

1. Kendin + 1–2 kişi **Internal Testing** (App Store Connect kullanıcıları).
2. Harici test için Beta App Review gerekir; ilk public release’ten önce şart değil.
3. Test checklist:

- [ ] E-posta ile kayıt / giriş
- [ ] Google ile giriş
- [ ] Apple ile giriş (iOS’ta zorunlu; Google varsa Apple da olmalı — Guideline 4.8)
- [ ] Onboarding
- [ ] Ücretsiz: görev, timeline, odak, AI sohbet limiti
- [ ] Premium satın al + restore
- [ ] Alt görev, çoklu profil, alarm, takvim aktarma (Premium)
- [ ] Widget / Live Activity (fiziksel cihaz)
- [ ] Mikrofon + konuşma tanıma
- [ ] Bildirim izni
- [ ] Ruh hali + (iOS 18) Apple Health
- [ ] Ayarlar → Hesabı sil
- [ ] Ayarlar → Gizlilik / Şartlar linkleri açılıyor
- [ ] iPad layout (universal olduğu için)

---

## 8. App Review’un reddetmemesi için

Apple’ın Florien özelinde bakacağı maddeler:

### 8.1 Hesap silme (5.1.1)

Ayarlar → **Hesabı sil** var; Cloud Function Auth + `users/{uid}` siler. Web yedek yol: https://www.wirefire.co/florien/delete-account

Review notuna yaz: “Account deletion is in Settings → Delete account.”

### 8.2 Sign in with Apple (4.8)

Google var → Apple da var. Tamam.

### 8.3 Abonelik (3.1.2)

Paywall’da fiyat mağazadan gelir; **Satın alımları geri yükle** butonu var. Şartlar’da yenileme / iptal anlatılıyor. Review’a paywall screenshot’ı ve “Restore Purchases is on the membership screen” yaz.

### 8.4 HealthKit

Ruh hali senkronu **iOS 18 State of Mind**. Tıbbi teşhis yok. Review notu örneği:

> HealthKit is optional and used only to read/write daily mood (HKStateOfMind) when the user enables Apple Health sync. Florien is not a medical or diagnostic app.

Privacy Nutrition Label’da Health verisini **Health & Fitness** altında, bağlı özelliğe özel, kullanıcıya bağlı olarak işaretle.

### 8.5 Konuşma tanıma / mikrofon

Sesle görev yazma. Ses kaydı sunucuda tutulmuyor (privacy metni). İzin diyalogları yerelleştirilmiş.

### 8.6 Yapay zekâ

İnceleme notu:

> AI runs on Google Gemini via Cloud Functions. It drafts tasks/plans; the user must confirm before items are added. It is not a health, legal, or crisis advisor.

### 8.7 Demo hesap

Reviewer’a **e-posta + şifre** ver. Sandbox IAP için ayrıca:

> Subscriptions: use the sandbox account on the review device. Product IDs: com.florien.app.subscription.monthly and …yearly.

Demo hesap production Firebase’de gerçek bir kullanıcı olsun; inceleme günü silinmesin.

### 8.8 Login duvarı

Hesapsız kullanılamıyorsa reviewer’ın takılmaması için demo hesap şart. Misafir akışı varsa notta belirt.

---

## 9. App Privacy (Nutrition Label)

App Store Connect → **App Privacy**. Florien’in mevcut koduna göre:

**Toplanmıyor gibi görünenler**

- Reklam kimliği / tracking
- Firebase Analytics / Crashlytics (privacy metnine göre kapalı)
- Konum, kamera, fotoğraf

**Toplanan / işlenen (örnek işaretleme — avukat/onay ile son kontrol)**

| Veri | Kullanım | Tracking? | Kullanıcıya bağlı? |
| --- | --- | --- | --- |
| E-posta, isim, kullanıcı ID | Hesap | Hayır | Evet |
| Kullanıcı içeriği (görev, not, ruh hali) | Uygulama işlevi | Hayır | Evet |
| Satın alma bilgisi (ürün, süre; kart yok) | Abonelik | Hayır | Evet |
| Ses (cihazda metne çeviri; saklanmıyor) | İşlev | Hayır | — |
| Sağlık (ruh hali, isteğe bağlı) | İşlev | Hayır | Evet |
| Takvim (isteğe bağlı aktarma) | İşlev | Hayır | Evet |
| Cihaz / tanı (Firebase altyapısı) | Güvenlik / işlev | Hayır | Karışık |

“Do you or your third-party partners use data for tracking?” → **No**.

Bu etiketler gizlilik sayfasıyla çelişirse reddedilir. Çelişki görürsen önce privacy sayfasını güncelle.

---

## 10. Mağaza listesi (metadata)

### 10.1 Ekran görüntüleri

Uygulama **iPhone + iPad**. Minimum:

| Cihaz sınıfı | Dikey boyut | Zorunlu |
| --- | --- | --- |
| iPhone 6.9" | 1320×2868, 1290×2796 veya 1260×2736 | Evet |
| iPad 13" | 2064×2752 veya 2048×2732 | Evet (universal) |

- 1–10 görsel, JPG/PNG, alfa yok.
- Önce EN; TR lokalizasyonuna aynı seti kopyalayabilirsin.
- Önerilen 6 kare: timeline, odak, AI, premium paywall, widget/Live Activity, istatistik/ruh hali.
- Cihaz çerçevesi serbest; metin okunaklı ve abartısız olsun (Guideline 2.3.7).

Opsiyonel: 15–30 sn App Preview videosu.

### 10.2 Metin (EN taslak — TR’yi lokalizasyona ekle)

**Name:** Florien  
**Subtitle (30 karakter):** Visual planner for focus  

**Description (kısa öneri):**

Florien is a visual daily planner for people who think in pictures, not long lists. Build a colorful timeline, start tasks, stay in focus mode, and break big work into small steps.

Free includes the timeline, to-dos, focus timer, and a small amount of AI chat. Premium adds AI that can turn suggestions into tasks, subtasks, extra profiles, calendar import, alarms, and custom times.

Florien is a planning tool. It is not medical, diagnostic, or crisis care.

**Keywords (100 karakter, virgülle, marka ismi tekrarlama):**  
`planner,visual,adhd,focus,routine,timeline,todo,calendar,neurodivergent,habit`

**What's New (1.0.0):**  
First release.

**Copyright:** `2026 Alperen Demirdöğer`

### 10.3 Fiyat ve bölgeler

Uygulama ücretsiz + IAP. Availability: istediğin ülkeler (Türkiye + ABD en azından).

---

## 11. İncelemeye gönderme

1. TestFlight’taki **en son yeşil** build’i seç.
2. IAP’ler bu sürüme bağlı ve Ready to Submit.
3. Export Compliance: encryption false ise atlanır.
4. Content rights, reklam kimliği (IDFA kullanmıyorsan hayır), reklam (yok).
5. **Add for Review** → **Submit**.

Durumlar: `Waiting for Review` → `In Review` → `Pending Developer Release` veya `Ready for Sale`.

Manuel yayın önerilir (`Manual Release`): onay gelince sen basarsın, sitenin / destek e-postasının ayakta olduğunu son kez kontrol edersin.

Onay sonrası:

1. Version Release → **Release this Version**.
2. 24 saat içinde mağazada görünür.
3. App Store URL:

```
https://apps.apple.com/app/id6799938907
```

Kodda `write-review` linki zaten bu ID’yi kullanıyor.

---

## 12. Yayın sonrası

İlk 48 saat:

- [ ] Firebase Usage / Functions hata oranı
- [ ] `appleServerNotifications` logları (yenileme / iptal)
- [ ] Gemini secret ve kota
- [ ] Cloud Billing
- [ ] App Store Connect crash / review notları
- [ ] Destek kutusunu (`support@wirefire.co`) izle
- [ ] 1 yıldız / abonelik şikayetlerine 24 saat içinde yanıt

Operasyon:

- Abonelik fiyat değişince App Store’dan yönet; uygulama metni `{price}` placeholder kullanır.
- AI limitleri: Firestore `appConfig/aiLimits`.
- Paywall metni: `appConfig/premiumPaywall`.
- Yeni iOS sürümü: `pubspec.yaml` version `1.0.1+N`, TestFlight, Submit.

---

## 13. Android (şimdilik değil)

İleride ayrı iş. Şimdilik yapma:

- Play Console uygulama oluşturma
- `google-services.json` / Android `firebase_options`
- Play Billing + Functions tarafı Google Publisher (README’de tarif var, iOS launch’ı bloklamaz)

---

## 14. Kontrol listesi

### A. Hukuk ve mağaza

- [ ] Paid Applications Agreement imzalı
- [ ] Banka + vergi tamam
- [ ] Privacy / Terms / Delete-account sayfaları canlı
- [ ] Support URL ve e-posta çalışıyor
- [ ] App Privacy etiketleri dolduruldu
- [ ] Yaş 16+ ile rating uyumlu
- [ ] Custom EULA URL’si bağlı

### B. Firebase

- [ ] Blaze + bütçe alarmı
- [ ] Auth: e-posta, Google, Apple production
- [ ] `firestore:rules` + `indexes` deploy
- [ ] `aiLimits` + `premiumPaywall` belgeleri
- [ ] `GEMINI_API_KEY` secret
- [ ] `APPLE_IAP_CREDENTIALS` secret
- [ ] Functions deploy edildi
- [ ] Apple test notification 200 OK
- [ ] Hesap silme function’ı denendi

### C. Apple teknik

- [ ] App ID + widget ID + App Group
- [ ] HealthKit, Sign in with Apple, Time Sensitive, App Groups
- [ ] Distribution cert + 2 profil
- [ ] Abonelik grup + 2 ürün Ready to Submit
- [ ] S2S V2 URL kayıtlı
- [x] Privacy manifest eklendi
- [ ] Encryption flag eklendi
- [ ] 1024 ikon alfa’sız

### D. Build ve inceleme

- [ ] TestFlight binary yüklendi
- [ ] Cihazda sandbox satın alma + restore
- [ ] Demo hesap
- [ ] iPhone 6.9" + iPad 13" ekran görselleri
- [ ] EN (ve TR) listing
- [ ] Review notları (HealthKit, AI, IAP, silme)
- [ ] Submit
- [ ] Onay sonrası Manual Release

---

## 15. Sık reddetme nedenleri (Florien’e özel)

| Risk | Önlem |
| --- | --- |
| IAP ürünleri “Missing Metadata” | Fiyat, yerelleştirme, review screenshot |
| Privacy URL 404 / uygulama içi link kırık | wirefire sayfalarını yayın öncesi aç |
| HealthKit ama listing “medical” iddiası | Metinde “not medical” |
| Sign in with Google, Apple yok | Zaten var; production’da kırık olmasın |
| Hesap silme sadece e-posta | Uygulama içi silme zorunlu — var |
| Eksik iPad screenshot | Universal target `1,2` |
| 1024 ikon şeffaf | Düz kare PNG |
| Subscription restore yok | Üyelik ekranında var |
| AI’yi sağlık tavsiyesi gibi satmak | Listing + review notu |
| Functions Spark’ta kalmış | Blaze |

---

## 16. Hızlı komut özeti

```bash
# Firebase
firebase use production
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm install && npm run build
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set APPLE_IAP_CREDENTIALS
firebase deploy --only functions

# iOS TestFlight (yerel)
cd mobile/ios
bundle exec fastlane beta

# iOS TestFlight (CI)
gh workflow run mobile-ios.yml -f deploy_testflight=true
```

İlgili diğer belgeler: `mobile/ios/TESTFLIGHT_SETUP.md`, `docs/ai-limits-config.md`, `docs/premium-paywall-config.md`.
