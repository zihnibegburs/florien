# Florien — Tiimo Benzeri Görsel Planlayıcı

> Nörodivergent kullanıcılar (ADHD, Otizm) ve görsel planlama ihtiyacı olan herkes için Tiimo tarzı bir uygulama.

## Tiimo Özellik Analizi

### Çekirdek Özellikler (Free Tier)
| Özellik | Açıklama | Öncelik |
|---------|----------|---------|
| Görsel Timeline | Renkli, saat bazlı günlük plan görünümü | P0 |
| To-Do Listesi | Beyin dökümü, önceliklendirme, güne sürükle-bırak | P0 |
| Görev Başlat/Duraklat | Timeline üzerinde aktif görev takibi | P0 |
| Odak Zamanlayıcı | Görsel geri sayım, geçiş yönetimi | P0 |
| Hatırlatıcılar | Push bildirim, titreşim, ses | P1 |
| Rutinler | Hazır rutin şablonları kütüphanesi | P1 |
| AI Checklist | Büyük görevleri adımlara bölme (5 ücretsiz) | P2 |
| Kutlama Animasyonları | Görev tamamlama geri bildirimi | P1 |

### Premium Özellikler (Pro Tier)
| Özellik | Açıklama | Öncelik |
|---------|----------|---------|
| Takvim Senkronizasyonu | Google, Apple, Outlook entegrasyonu | P2 |
| Widget'lar | Ana ekran / kilit ekranı widget'ları | P2 |
| Kişiselleştirme | 3000+ renk, emoji, özel ikon, ses | P1 |
| AI Co-Planner | Premium AI planlama, zaman tahmini | P2 |
| Haftalık Görünüm | Web/masaüstü haftalık plan | P2 |
| Çoklu Profil | 5 kullanıcıya kadar aile paylaşımı | P3 |
| Mood Check-in | Günlük ruh hali takibi ve analiz | P2 |
| Cross-device Sync | Tüm cihazlarda anlık senkron | P0 |

### Erişilebilirlik & UX
- Esnek planlama (yeniden düzenleme, taze başlangıç)
- Görsel öğrenenler için renk/ikon sistemi
- Düşük uyarı yorgunluğu (gentle nudges)
- Özelleştirilebilir fontlar ve sesler
- Sesli giriş (AI planlama için)

---

## Florien Teknoloji Stack

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Flutter App    │────▶│  Spring Boot API │────▶│ PostgreSQL  │
│  (iOS/Android)  │     │  (REST + JWT)    │     │  (Ana DB)   │
└─────────────────┘     └────────┬─────────┘     └─────────────┘
                                 │
                        ┌────────▼─────────┐
                        │      Redis       │
                        │ (Cache, Session, │
                        │  Notification Q) │
                        └──────────────────┘
```

| Katman | Teknoloji |
|--------|-----------|
| Mobile | Flutter 3.x, Riverpod, GoRouter, Dio |
| Backend | Spring Boot 3.2, Spring Security, JWT |
| Database | PostgreSQL 16 |
| Cache/Queue | Redis 7 |
| AI (Phase 6) | Firebase + Gemini |
| Push (Phase 4) | Firebase Cloud Messaging |

---

## Geliştirme Fazları

### Phase 1 — Temel Altyapı & MVP Timeline ✅
- [x] Proje iskeleti (Flutter + Spring Boot)
- [x] Docker Compose (PostgreSQL + Redis)
- [x] Kullanıcı kayıt/giriş (JWT)
- [x] Görev CRUD API
- [x] Günlük timeline API
- [x] Flutter: Auth ekranları
- [x] Flutter: Görsel timeline UI
- [x] Görev ekleme/düzenleme

### Phase 2 — Aktif Görev & Odak Modu ✅
- [x] Görev başlat/duraklat/tamamla state machine (resume desteği)
- [x] Görsel odak zamanlayıcı (circular progress)
- [x] Aktif görev banner'ı (geri sayım + odak ekranına geçiş)
- [x] Görev tamamlama kutlaması (confetti animasyon)
- [x] Redis: aktif görev session cache (pause süresi takibi)
- [x] Saat ızgarası timeline görünümü
- [x] Odak modu tam ekran (`/focus`)

### Phase 3 — To-Do & Rutinler
- Beyin dökümü inbox (tarihsiz görevler)
- Sürükle-bırak ile güne atama
- Rutin şablonları (sabah rutini, iş rutini vb.)
- Rutin → günlük plana tek tıkla ekleme
- Rutin kütüphanesi (hazır şablonlar)

### Phase 4 — Hatırlatıcılar & Bildirimler
- Push notification (FCM)
- Görev başlangıç/bitiş hatırlatıcıları
- Özelleştirilebilir ses ve titreşim
- Redis pub/sub ile bildirim kuyruğu
- Snooze ve gentle nudge mantığı

### Phase 5 — Kişiselleştirme
- Renk paleti (3000+ renk veya HSL picker)
- İkon/emoji kütüphanesi
- Özel ses seçimi
- Tema (açık/koyu/yüksek kontrast)
- Kullanıcı profil ayarları

### Phase 6 — AI Co-Planner ✅ (Firebase + Gemini)
- [x] Görev parçalama (checklist oluşturma) — `assistBreakdown`
- [x] Doğal dil ile günlük plan — `assistPlan`
- [x] Plan asistanı sohbeti — `assistPlannerChat`
- [x] Zaman tahmini (her adım/görev için dakika)
- [x] Flutter AI ekranı (Gün Planla / Görev Böl)
- [x] Planı güne tek tıkla ekleme
- [x] Firebase Cloud Functions üzerinden Gemini entegrasyonu
- [ ] Öncelik önerisi (ileride)
- [ ] Sesli giriş (ileride)

### Phase 7 — Takvim & Senkronizasyon
- Google Calendar OAuth2 entegrasyonu
- İki yönlü takvim senkronizasyonu
- Haftalık görünüm (web + mobile)
- Cross-device real-time sync (WebSocket)

### Phase 8 — Mood & Analitik
- Günlük mood check-in
- Enerji/focus pattern analizi
- Haftalık/aylık özet raporları
- Rutin optimizasyon önerileri

### Phase 9 — Widget & Platform ✅
- [x] iOS/Android home screen widget (home_widget + native UI)
- [x] Live Activities + Dynamic Island (iOS Swift)
- [x] Android Live Activity (RemoteViews)
- [ ] Apple Watch companion (opsiyonel — kapsam dışı)
- [x] Web uygulaması (Flutter Web + haftalık görünüm + responsive shell)

### Phase 10 — Monetizasyon & Çoklu Profil
- Free vs Pro tier
- Abonelik yönetimi (RevenueCat / Stripe)
- Aile profilleri (5 kullanıcı)
- Admin panel

---

## Veri Modeli (Özet)

```
User
├── Profile (displayName, avatarColor, preferences)
├── Tasks (title, duration, color, icon, status, scheduledAt)
├── Routines (name, steps[], repeatPattern)
├── MoodEntries (date, mood, energy, notes)
├── CalendarConnections (provider, tokens)
└── Subscription (tier, expiresAt)

TaskStatus: PENDING | IN_PROGRESS | PAUSED | COMPLETED | SKIPPED
```

---

## API Endpoint Planı

```
POST   /api/v1/auth/register
POST   /api/v1/auth/login
GET    /api/v1/auth/me

GET    /api/v1/tasks?date=2026-07-01
POST   /api/v1/tasks
PUT    /api/v1/tasks/{id}
DELETE /api/v1/tasks/{id}
POST   /api/v1/tasks/{id}/start
POST   /api/v1/tasks/{id}/pause
POST   /api/v1/tasks/{id}/complete

GET    /api/v1/focus/session

GET    /api/v1/timeline?date=2026-07-01
GET    /api/v1/inbox
POST   /api/v1/inbox/{taskId}/schedule

GET    /api/v1/routines
POST   /api/v1/routines
POST   /api/v1/routines/{id}/apply

POST   /api/v1/ai/breakdown
POST   /api/v1/ai/plan

GET    /api/v1/mood?from=&to=
POST   /api/v1/mood
```
