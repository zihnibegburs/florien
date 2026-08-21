# Florien

Tiimo tarzı görsel günlük planlayıcı — Flutter + Firebase (Auth, Firestore, Cloud Functions).

## Hızlı Başlangıç

```bash
# 1. Firebase projesi oluştur (Console) ve Auth provider'ları aç:
#    Email/Password, Google, Apple

# 2. FlutterFire config
cd mobile
dart pub global activate flutterfire_cli
flutterfire configure
# → mobile/lib/firebase_options.dart dolar

# 3. Firestore rules & indexes + Functions
cd ..
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm install && npm run build
firebase functions:secrets:set APPLE_IAP_CREDENTIALS
firebase deploy --only functions

# 4. Uygulamayı çalıştır
cd mobile && flutter run
```

## Proje Yapısı

```
Florien/
├── docs/PLAN.md          # Ürün / faz planı
├── firebase.json         # Firestore + Functions
├── firestore.rules
├── functions/            # Protected Gemini AI Cloud Functions
├── backend/              # Eski Spring Boot API (deprecated)
└── mobile/               # Flutter uygulaması
```

## Firestore şema

```
users/{uid}
  email, displayName, avatarColor, settings{...}
  tasks/{taskId}
    title, scheduledAt, status, isInbox, subtasks via parentTaskId, …
  review_feedback/{feedbackId}            # 1–3 yıldız sorun/öneri geri bildirimi
    rating, issue, suggestion, createdAt
  private/aiAccess                         # Admin SDK only
    premiumUntil, premiumProvider, usage{minute,hour,day,month}

premiumTransactions/{sha256}              # Admin SDK only; purchase ownership
```

## Auth

- Email / Password
- Google Sign-In
- Sign in with Apple

## AI (Cloud Functions)

| Callable | Açıklama |
|----------|----------|
| `assistBreakdown` | Görevi adımlara böl |
| `assistPlan` | Doğal dilden günlük plan |
| `assistPlannerChat` | Planner kapsamlı sohbet ve onaylanabilir To-do taslakları |
| `verifyPremiumPurchase` | Apple/Google satın alımını doğrula ve private entitlement yaz |
| `getPremiumStatus` | Sunucudaki aktif Premium durumunu istemciye döndür |

AI callable'ları kullanıcı kimliğini ve server-verified Premium entitlement'ı
kontrol eder. Kullanım rezervasyonu `users/{uid}/private/aiAccess` üzerinde tek
Firestore transaction'ıyla yapılır. Sabit limitler: 5/dakika, 30/saat,
100/gün ve 3.000/ay.

AI üretimi API anahtarı olmadan Cloud Functions servis hesabıyla Gemini
üzerinden çalışır. Merkezi model seçimi `functions/src/ai-config.ts`
dosyasındadır. Functions runtime servis hesabında Vertex AI User yetkisi ve
projede Vertex AI API etkin olmalıdır.

Premium kapsamı: AI plan sohbeti, alt görev oluşturma, birden fazla profil,
Apple/Google takvim aktarma, alarm/hatırlatıcı ve göreve özel saat seçimi.
Alt görev, alarm, özel saat ve ikincil profil görev yazımları istemci
manipülasyonuna karşı Firestore Rules ile de korunur.

`APPLE_IAP_CREDENTIALS` JSON secret alanları:

```json
{
  "sharedSecret": "App Store subscription shared secret",
  "issuerId": "App Store Connect issuer id",
  "keyId": "In-App Purchase key id",
  "privateKey": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----"
}
```

Google Play doğrulaması için Android Publisher API etkin olmalı ve Functions
runtime service account'u Play Console'a eklenerek abonelikleri/siparişleri
okuma yetkisi verilmelidir. Apple tarafında App Store Connect In-App Purchase
anahtarı ve abonelik shared secret'ı gerekir.

Spring Boot `backend/` klasörü artık Flutter tarafından kullanılmıyor; ileride kaldırılabilir.
