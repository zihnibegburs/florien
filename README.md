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
firebase functions:secrets:set GROQ_API_KEY
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
├── functions/            # AI assist (Groq) Cloud Functions
├── backend/              # Eski Spring Boot API (deprecated)
└── mobile/               # Flutter uygulaması
```

## Firestore şema

```
users/{uid}
  email, displayName, avatarColor, settings{...}
  tasks/{taskId}
    title, scheduledAt, status, isInbox, subtasks via parentTaskId, …
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

Spring Boot `backend/` klasörü artık Flutter tarafından kullanılmıyor; ileride kaldırılabilir.
