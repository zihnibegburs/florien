# AI kullanım limitleri yapılandırması

AI sohbet ve Premium AI özelliklerinin limitleri Firestore'daki
`appConfig/aiLimits` belgesinden yönetilir. Belge istemciler tarafından
yalnızca okunabilir; yazma işlemi Firebase Console veya Admin SDK ile yapılır.

```json
{
  "freeChatMessagesPerMonth": 3,
  "premiumMessagesPerMinute": 5,
  "premiumMessagesPerHour": 30,
  "premiumMessagesPerDay": 100,
  "premiumMessagesPerMonth": 3000,
  "geminiModelName": "gemini-3.1-flash-lite"
}
```

## Alanlar

| Alan | Kim için | Açıklama |
| --- | --- | --- |
| `freeChatMessagesPerMonth` | Ücretsiz kullanıcı | AI sohbette aylık mesaj hakkı. Planner red mesajları ve görev önerileri dahil her istek 1 sayılır. |
| `premiumMessagesPerMinute` | Premium | Dakikalık AI isteği üst sınırı (sohbet + alt görev + plan birlikte sayılır). |
| `premiumMessagesPerHour` | Premium | Saatlik üst sınır. |
| `premiumMessagesPerDay` | Premium | Günlük üst sınır. |
| `premiumMessagesPerMonth` | Premium | Aylık üst sınır. |

Belge yoksa veya bir alan eksikse Cloud Functions varsayılan değerleri kullanır.

## İlk kurulum

Firestore'da belge otomatik oluşmaz. Firebase Console'dan elle ekleyebilir veya:

```bash
cd functions && npm run seed:ai-limits
```

(komut `firebase login` veya `gcloud auth application-default login` gerektirir)

Console yolu: **Firestore Database → Start collection** (veya mevcut `appConfig` koleksiyonu)
→ Document ID: `aiLimits` → alanları yukarıdaki JSON ile ekle.

## Freemium davranışı

- Ücretsiz kullanıcı AI sohbeti açabilir ve ayda `freeChatMessagesPerMonth` kadar mesaj gönderebilir.
- Görev önerileri ekranda gösterilir; **To-do'ya eklemek Premium gerektirir**.
- Alt görev (`assistBreakdown`) ve günlük plan (`assistPlan`) hâlâ yalnızca Premium içindir.

## Sayaç sıfırlama

Aylık sayaç UTC ayın 1'inde sıfırlanır. Kullanıcı bazlı sayaç
`users/{uid}/private/aiAccess.usage` altında tutulur (yalnızca Admin SDK erişir).
