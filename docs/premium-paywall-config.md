# Premium paywall metin yapılandırması

Plan kartlarının metinleri Firestore'daki `appConfig/premiumPaywall`
belgesinden yönetilir. Belge istemciler tarafından yalnızca okunabilir; yazma
işlemi Firebase Console veya Admin SDK ile yapılır.

```json
{
  "localizations": {
    "tr": {
      "planSectionTitle": "Planını seç",
      "monthlyTitle": "Aylık",
      "monthlyPeriod": "Her ay yenilenir",
      "monthlyBadge": "Esnek",
      "yearlyTitle": "Yıllık",
      "yearlyPeriod": "Yılda bir yenilenir",
      "yearlyBadge": "En avantajlı",
      "priceTemplate": "{price}",
      "dailyPriceTemplate": "Günde yaklaşık {price}",
      "purchaseCtaTemplate": "{price} karşılığında Premium ol"
    },
    "en": {
      "planSectionTitle": "Choose your plan",
      "monthlyTitle": "Monthly",
      "monthlyPeriod": "Renews every month",
      "monthlyBadge": "Flexible",
      "yearlyTitle": "Yearly",
      "yearlyPeriod": "Renews once a year",
      "yearlyBadge": "Best value",
      "priceTemplate": "{price}",
      "dailyPriceTemplate": "About {price} per day",
      "purchaseCtaTemplate": "Get Premium for {price}"
    }
  }
}
```

`{price}` alanı zorunludur. Uygulama bu alanı App Store veya Google Play'in
kullanıcının ülkesine göre verdiği yerelleştirilmiş fiyatla değiştirir. Sayısal
fiyat ve para birimi mağaza panellerinden yönetilir; Firestore metni gerçek
tahsilat tutarını değiştiremez.

Yeni bir uygulama dili eklendiğinde aynı dil koduyla yeni bir `localizations`
alanı eklenmelidir. Bir alan veya dil eksikse uygulama kendi yerelleştirilmiş
varsayılan metnine döner.
