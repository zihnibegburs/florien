# Tekrarlayan görevler

Günlük planda “Her gün / Her hafta / Her ay” seçilerek yaratılan görev, takvimde her gün için ayrı kopya olarak saklanmaz. Veritabanında **bir şablon (master)** durur; o günün kartı okuma anında **şablon ⊕ yama** ile üretilir.

---

## 1. Model

Örnek: 26 Ağustos sabah 08:00, “İlaç”, her gün.

### Şablon (master)

Tek gerçek seri kaydı. `recurrenceType = DAILY`, `recurrenceSeriesId` ve `recurrenceRootId` kendi id’si. Timeline’da görünmez.

### Sanal gün (`r:{seriId}:{yyyy-MM-dd}`)

Henüz dokunulmamış kopya. Firestore’da yok. Tamamlama, odak, isim gibi bir yazma o günü istisnaya çevirir.

### İstisna (exception)

O güne özel kayıt. İki tür:

| Tür | Anlamı |
| --- | --- |
| `OVERRIDE` | Bu gün var; sapmalar yamada |
| `SKIP` | Bu gün yok (silindi) |

`OVERRIDE` **seyrek yama**dır. `recurrenceOwnedFields` hangi alanların bu güne ait olduğunu tutar.

- `[]` (yeni istisna): durum / tamamlanma bu güne aittir; isim, grup, saat şablondan gelir.
- `["title"]`: isim bu güne özel; grup şablonu izler.
- Alan yok (`null`): eski tam klon. Şablon güncellemesi bu kaydı hâlâ alan alan yazar.

Okuma: `mergeRecurrenceException(şablonGünü, istisna)`.

### Üç kapsam

| Kapsam | Anlamı |
| --- | --- |
| **Bunu** (`THIS`) | Sadece açık olan gün. Yama. |
| **Gelecektekileri** (`FUTURE`) | Bu günden yeni şablon. Eski şablon burada biter. Bu günden sonraki istisnalar yeni seriye taşınır. |
| **Hepsini** (`ALL`) | Kökteki şablonlar. Seyrek yamadaki özel alanlar (ör. isim) korunur; sahip olunmayan alanlar (ör. grup) şablonu izler. |

---

## 2. Kapsam tablosu

Tek yazma yolu: `updateRecurringTask` / `completeTask` / `toggleSubtask` / `deleteTask`. Ekran kapsam uydurmaz; tabloya uyar.

| Aksiyon | Sorar | Kapsam | Nereye yazar |
| --- | --- | --- | --- |
| Tamamla / geri al / odak | Hayır | `THIS` | yama (durum) |
| Tamamlandıya sürükle | Hayır | `THIS` | yama |
| Grup / saat sürükle | Özel isimli gün: hayır. Diğerleri: evet | Özel isim: `THIS`. Soru: seçilen | `THIS` o günün grubu; `ALL` şablon + özel isimli günler de yeni grubu izler, isim kalır |
| Düzenle | Evet | Seçilen | `THIS` yama + owned alan; `ALL` şablon; `FUTURE` kesim |
| Sil | Evet | Seçilen | `THIS` skip; `FUTURE` until + sonraki istisnalar silinir; `ALL` ağaç |
| Yeniden planla / yarın | Evet (seri ise) | Seçilen | `THIS` o günü taşır (`occurrenceDate`); gün sonu incelemesi sormadan `THIS` |
| Yapılacaklara taşı | Hayır | `THIS` | o gün inbox; seri devam |
| Kopya | Hayır | — | yeni tek görev, yinelemesiz |
| Ayrım öner | Hayır | alışkanlık | şablon alt görev tanımı; kendi çocuğu olan istisnalar da |
| Alt görev kutusu | Hayır | `THIS` | o günün kopyası; şablon tiklenmez |

Tek seferlik görevi düzenleyip “her gün” yapmak `recurrenceSeriesId` / `rootId` basar.

---

## 3. Alt görevler

Tanım şablondadır. Sanal gün şablon listesini **gösterir**; kutu o günü materialize edip kopya çocuk yazar. Ertesi sanal gün yine boş şablon görür.

Tüm kopya adımlar bitince `OVERRIDE` tamamlanabilir. Şablon (`isSeriesMaster`) alt görevlerden otomatik tamamlanmaz.

---

## 4. Bildirim ve widget

Zamanlı seri 14 gün sanal genişler. Tamamlama (uygulama, bildirim, widget) `TaskRepository.completeTask` kullanır; sanal id materialize olur. Ham `doc(r:…)` yazılmaz.

---

## 5. Kesim (`FUTURE`)

Eski master `recurrenceUntil` alır. Yeni master aynı `recurrenceRootId` ile başlar; şablon alt görevleri kopyalanır. `occurrenceDate >= kesim` istisnaları yeni `recurrenceSeriesId` alır. Çift kart çıkmaz. Kesimden sonraki skip/override eski seride bırakılmaz.

`FUTURE` silme, o günden sonraki istisnaları da siler.

---

## 6. Firestore

İstisna sorgusu: `recurrenceSeriesId` + `occurrenceDate` (`firestore.indexes.json`). Production’a deploy edilmezse istisna okunması kırılır.

Yeni alan: `recurrenceOwnedFields` (`string[]`). Yoksa eski tam klon davranışı.

---

## 7. Elle deneme

1. İleri tarih — kopya yığılmadan kart.
2. Bir günü yeniden adlandır (`THIS`) — komşu gün eski isim.
3. Adı değişmemiş günü akşam → sabah sürükle — Bunu / Gelecektekileri / Hepsini sor. Adı değişmiş günü sürükle — sormadan sadece o gün taşınır. Hepsini seçilirse adlandırılmış gün de yeni grubu izler, isim kalır.
4. Düzenle → Hepsini ile başlık — özel isimli gün kendi adını tutar, diğerleri yeni isim.
5. Sanal günde alt görev işaretle — sadece o gün; ertesi gün boş.
6. Bir günü sil (`THIS`) / gelecektekileri sil / hepsini sil.
7. `THIS` istisnasından sonra başka günden `FUTURE` — tek kart, özel isim yeni seride.
8. Widget / bildirim ile sanal günü tamamla.
9. 31’inde aylık — Şubat boş kalır (aynı gün numarası).
