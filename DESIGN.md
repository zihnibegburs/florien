# Florien Design System

> Bu belge Florien mobil uygulamasının görsel ve etkileşim kurallarını tanımlar. Yeni ekranlar ve bileşenler bu kuralları izlemeli; gerçek tasarım token'larının teknik kaynağı `mobile/lib/core/theme/florien_theme.dart` olmalıdır.

## 1. Tasarım yönü

Florien'in tasarım dili **yumuşak neo-brutalizm**, sıcak pastel yüzeyler ve organik AI hareketlerinden oluşur. Arayüz enerjik görünmeli fakat dikkat dağıtmamalıdır. Özellikle nöroçeşitli kullanıcılar için her ekranda net bir öncelik, düşük bilişsel yük ve öngörülebilir etkileşim korunur.

### Tasarım karakteri

- Sıcak, iyimser ve destekleyici
- Belirgin siyah konturlar; gölge yerine yüzey ayrımı
- Büyük yuvarlatmalar ve pill biçimli kontroller
- Sarı ana vurgu, pastel destek renkleri
- Güçlü fakat kısa başlıklar
- Organik AI görselleri; kontrollü ve anlamlı hareket
- Tek ekranda tek baskın eylem

### Temel ilkeler

1. **Önce netlik:** Görsel oyun, görevin ve metnin önüne geçmez.
2. **Birincil eylem tektir:** Aynı bölümde iki sarı CTA kullanılmaz.
3. **Renk anlam taşır ama tek başına anlam değildir:** Durumlar ikon, metin veya biçimle de belirtilir.
4. **Derinlik konturla kurulur:** Varsayılan yüzeylerde gölge ve cam efekti kullanılmaz.
5. **Hareket işlevseldir:** Durum değişimini veya AI etkinliğini açıklar; sürekli dekoratif hareketten kaçınılır.
6. **Mevcut primitive'ler yeniden kullanılır:** Yeni bir kart, buton veya navigasyon varyantı oluşturmadan önce `florien_ui.dart` kontrol edilir.

## 2. Görsel hiyerarşi

Tipik ekran sırası:

1. Ekran başlığı veya kullanıcının mevcut bağlamı
2. O an yapılması gereken tek ana eylem
3. Yakın dönem içeriği veya görev listesi
4. İkincil bilgiler ve gelişmiş seçenekler
5. Sabit/yüzen alt navigasyon

Ana içerik sıcak nötr yüzeylerde kalır. Sarı, kullanıcının bakması veya dokunması gereken yeri işaretler. Lavanta ve açık mavi AI alanlarını; mint ve lime olumlu ilerlemeyi; pembe ise dikkat gerektiren fakat hata olmayan durumları destekler.

## 3. Renk sistemi

### 3.1 Çekirdek renkler

| Token | Hex | Rol |
|---|---:|---|
| `primary` | `#FFF76A` | Ana CTA, seçili durum, önemli vurgu |
| `primaryLight` | `#FFF9A8` | Hafif sarı yüzey |
| `onPrimary` | `#171717` | Sarı üzerindeki metin ve ikon |
| `accentText` | `#765415` | Açık zeminde koyu vurgu ve etkileşim rengi |
| `focusAccent` | `#F2BC52` | Klavye odağı ve dikkat vurgusu |
| `background` | `#FAF9F6` | Açık tema ekran zemini |
| `surface` | `#FFFFFF` | Kart, modal ve kontrol yüzeyi |
| `surfaceMuted` | `#F3F1EC` | Pasif veya ikincil yüzey |
| `textPrimary` | `#171717` | Ana metin ve kontur |
| `textSecondary` | `#6B6B70` | Yardımcı metin |
| `border` | `#171717` | Açık temada yapısal kontur |

Referans UI'daki sarı yaklaşık `#FFFB8F` olsa da Florien'in kanonik marka sarısı `#FFF76A`'dır. Ekran içinde yeni sarı tonlar üretilmemelidir.

### 3.2 Pastel destek renkleri

| Token | Hex | Önerilen kullanım |
|---|---:|---|
| `accent` | `#C4B5FD` | Seçili ikincil kategori, istatistik |
| `aiAccent` | `#A78BFA` | AI vurgusu ve gradyan |
| `aiLavender` | `#E9E2FF` | AI kartı veya yardımcı AI yüzeyi |
| `paleBlue` | `#BCEEFF` | Planlama, bilgi ve AI yüzeyi |
| `mint` | `#B8F2D0` | Tamamlanma, iyi durum, sakin başarı |
| `softLime` | `#DDFC83` | Enerji ve hafif olumlu vurgu |
| `softPink` | `#FFD6E7` | Hatırlatma, hassas veya dikkat isteyen içerik |

Pasteller metin renginin yerini almaz. Pastel yüzey üzerinde varsayılan metin `textPrimary` olmalıdır.

### 3.3 Semantik renkler

| Durum | Hex | Kural |
|---|---:|---|
| Başarılı | `#2F9E6B` | Tamamlanma ve pozitif sonuç |
| Uyarı | `#D97706` | Kullanıcı karar vermeli veya kontrol etmeli |
| Hata | `#DC2626` | Hata, başarısız işlem veya yıkıcı eylem |

Semantik renkler dekoratif kullanılmaz. Hata ve uyarı her zaman açıklayıcı metin ve gerekirse ikonla birlikte gösterilir.

### 3.4 AI gradyanı

Kanonik sıra:

```text
#BCEEFF -> #A78BFA -> #DDFC83 -> #FFF76A
```

Gradyan yalnızca AI kimliği, AI kenarlığı, AI FAB veya AI hareket varlıklarında kullanılır. Standart butonlarda, metinlerde ve geniş ekran zeminlerinde kullanılmaz.

### 3.5 Renk dağılımı

- `%65–75` nötr zemin ve yüzey
- `%15–25` pastel destek yüzeyi
- `%5–10` sarı marka/aksiyon vurgusu
- En fazla bir baskın pastel bölüm veya büyük AI görseli

### 3.6 Koyu tema

| Rol | Hex |
|---|---:|
| Arka plan | `#29292B` |
| Yüzey | `#333336` |
| Hafif yüzey | `#3A3A3E` |
| Ana metin | `#F7F7F5` |
| Yardımcı metin | `#B7B7BA` |
| Kontur | `#4A4A4E` |
| Sarı muted yüzey | `#4A4630` |
| AI yüzeyi | `#3A3550` |

Koyu tema açık temanın ters çevrilmiş hali değildir. Sarı yine vurgu olarak kalır; geniş sarı yüzeylerden kaçınılır ve konturlar daha yumuşak kullanılır.

## 4. Tipografi

Florien'in kanonik yazı ailesi **Manrope**'tur ve `google_fonts` üzerinden yüklenir.

```dart
GoogleFonts.manropeTextTheme(...)
```

| Stil | Boyut | Ağırlık | Satır yüksekliği | Harf aralığı | Kullanım |
|---|---:|---:|---:|---:|---|
| `displaySmall` | 30 | 800 | 1.10 | -0.8 | Hero veya tek ana mesaj |
| `headlineLarge` | 28 | 800 | 1.15 | -0.7 | Ekran başlığı |
| `headlineMedium` | 22 | 700 | varsayılan | -0.4 | Büyük bölüm başlığı |
| `titleLarge` | 20 | 700 | varsayılan | -0.3 | Bölüm başlığı |
| `titleMedium` | 17 | 700 | varsayılan | 0 | Kart başlığı |
| `titleSmall` | 14 | 600 | varsayılan | 0 | Küçük başlık |
| `bodyLarge` | 16 | 500 | 1.35 | 0 | Ana gövde metni |
| `bodyMedium` | 14 | 500 | 1.35 | 0 | Yardımcı metin |
| `labelLarge` | 15 | 700 | varsayılan | 0 | Büyük buton etiketi |
| `labelMedium` | 13 | 600 | varsayılan | 0 | Chip ve kompakt kontrol |
| `labelSmall` | 12 | 600 | varsayılan | 0 | Metadata ve navigasyon |

### Tipografi kuralları

- Başlıklarda en fazla iki ağırlık kullanın: `700` ve `800`.
- Gövde metnini `14px` altına düşürmeyin; yalnızca kısa metadata `12px` olabilir.
- Başlıklar mümkün olduğunca iki satırı geçmemelidir.
- Türkçe metinlerde cümle düzeni kullanın; Her Kelimeyi Büyük Harfle Başlatmayın.
- Büyük harf kullanımı yalnızca kısa kategori/etiket veya marka ifadesiyle sınırlıdır.
- Metin içine renkli gradyan uygulanmaz.
- Dinamik yazı boyutunda metin kesilmemeli; kartlar sabit metin yüksekliğine bağlanmamalıdır.

## 5. Ölçü ve yerleşim

### 5.1 Boşluk token'ları

| Token | Değer |
|---|---:|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 20 |
| `xxl` | 24 |
| `xxxl` | 32 |
| `huge` | 40 |
| `screen` | 20 |

Kurallar:

- Ekranların standart yatay marjı `20px`.
- Bir kartın standart iç boşluğu `24px`; yoğun kartlarda `16px`.
- Birbirine bağlı öğeler arasında `8–12px`, farklı bölümler arasında `24–32px` kullanın.
- Rastgele ölçü eklemeyin. Önce yukarıdaki token'lardan birini seçin.
- Scroll içeriği, yüzen alt navigasyon tarafından örtülmeyecek kadar alt boşluk taşımalıdır.

### 5.2 Köşe yarıçapları

| Token | Değer | Kullanım |
|---|---:|---|
| `xs` | 10 | Küçük badge/ikon yüzeyi |
| `sm` | 14 | Kompakt kontrol |
| `md` | 18 | Input, liste satırı |
| `lg` | 24 | Standart kart |
| `xl` | 28 | Sheet, büyük panel |
| `xxl` | 32 | Hero veya geniş vurgu kartı |
| `pill` | 999 | Buton, chip, navigasyon seçimi |

Aynı bileşende iç ve dış radius farkı genellikle `1–4px` olmalıdır.

### 5.3 Kontur ve yükseklik

- Standart kontur: `1.25px`
- Odak veya yüksek vurgu konturu: `1.5px`
- Varsayılan elevation: `0`
- Kartlar ve modal yüzeyler siyah/tema konturuyla ayrılır.
- Gölge yalnızca platformun zorunlu olarak beklediği geçici yüzeylerde ve çok hafif kullanılabilir.

## 6. İkon ve görsel dil

- Birincil ikon seti `flutter_icon_park`; yuvarlak uçlu ve tutarlı stroke tercih edilir.
- Genel ikon boyutu `22–24px`; navigasyon `20px`; buton içi ikon `18px`.
- Aynı ekranda farklı ikon aileleri karıştırılmaz.
- İkon tek başına kritik anlam taşıyorsa tooltip ve semantik etiket zorunludur.
- Dekoratif emoji kullanılmaz.
- Logo `assets/brand/florien-symbol-color.png` kaynağından `FlorienLogo` ile gösterilir; kodla yeniden çizilmez.
- AI kimliği `assets/ai/florien_ai_flow.json` ve `FlorienAiAnimation` ile gösterilir.
- 3D/organik varlıklar şeffaf arka planlı, yumuşak ışıklı ve aynı malzeme dilinde olmalıdır. Ekran başına bir ana görsel yeterlidir.

## 7. Bileşen kuralları

### 7.1 Butonlar

**Birincil buton**

- `FlorienPrimaryButton` kullanılır.
- Yükseklik `54px`, pill radius, sarı yüzey ve koyu kontur.
- Bir görünür bölümde yalnızca bir birincil buton bulunur.
- Etiket eylem fiiliyle başlar: “Planı oluştur”, “Görevi ekle”.
- Basılı durum `0.97` ölçek ve `120ms` ile verilir.

**İkincil buton**

- `FlorienSecondaryButton` kullanılır.
- Beyaz/tema yüzeyi, koyu kontur; birincil eylemle rekabet etmez.

**İkon butonu**

- Minimum `44×44px` dokunma alanı.
- `tooltip` boş bırakılmaz.
- Sık kullanılan aksiyonlarda ikonun yanında metin tercih edilir.

### 7.2 Kartlar

- Genel içerik için `FlorienCard`.
- Görev satırı için `FlorienTaskCard`.
- Varsayılan radius `24px`, kontur `1.25px`, padding `24px`.
- Tıklanabilir kartta tüm yüzey dokunulabilir olmalı; ayrıca kart içine gereksiz ikinci CTA eklenmemelidir.
- Tamamlanmış görev yalnızca opacity ile değil, işaret/etiket/metin durumu ile de açıklanmalıdır.
- Pastel kart rengi içeriğin kategorisini destekler; okunabilirliği düşürmemelidir.

### 7.3 Input'lar

- Standart radius `18px`, yatay padding `18px`, dikey padding `16px`.
- Label, yardımcı metin ve hata metni alanın dışında da okunabilir kalmalıdır.
- Placeholder label yerine geçmez.
- Odak durumunda kontur `1.5px` olur; yalnızca renk değişimine güvenilmez.
- Gönderme ve ses düğmeleri minimum `46×46px` olarak korunur.

### 7.4 Chip ve seçimler

- Pill formu kullanılır.
- Seçili durum sarı dolgu + koyu metin/kontur ile belirtilir.
- Bir grupta çok fazla pastel renk kullanılmaz; seçili/seçili değil ayrımı önceliklidir.

### 7.5 Alt navigasyon

- `FlorienBottomNavigation` kullanılır.
- Yükseklik `68px`; ekran yatay marjı `20px`.
- En fazla dört ana hedef ve ayrı bir `FlorienAiFab` önerilir.
- Seçili öğe sarı pill, dolu ikon ve güçlü label ile belirtilir.
- Seçili olmayan ikonlar düşük vurgu alır fakat erişilebilir kontrast korunur.
- Scroll içeriği için navigasyon yüksekliği, padding ve safe area dahil yeterli alt boşluk ayrılır.
- Navigasyon rotaları kullanıcı bağlamını ve scroll konumunu mümkün olduğunca korur.

### 7.6 AI yüzeyleri

- AI, lavanta/açık mavi yüzey veya kontrollü AI gradyanıyla ayırt edilir.
- AI FAB yalnızca AI'ya doğrudan giriş görevi görür; genel “ekle” aksiyonu yerine kullanılmaz.
- AI mesajlarında asistan yüzeyi solda, kullanıcı yüzeyi sağda konumlanır.
- AI önerileri kesin sonuç gibi sunulmaz; düzenlenebilir ve geri alınabilir olmalıdır.
- Yükleme, dinleme ve üretim durumları hem görsel hem metinsel geri bildirim verir.

### 7.7 Modal, sheet ve dialog

- Büyük seçim ve çok adımlı kısa işlemler bottom sheet'te açılır.
- Sheet üst radius `28px`; dialog radius `24px`.
- Yıkıcı eylem birincil sarı butonla gösterilmez; semantik hata rengi ve açık metin kullanılır.
- Modal açıldığında ilk odak anlamlı kontrole gider ve kapatma yolu görünürdür.

## 8. Ekran şablonları

### Ana planlama ekranı

1. Selamlama veya gün bağlamı
2. Günün en önemli aksiyonu
3. Zaman çizelgesi/görev listesi
4. İkincil öneriler
5. Yüzen alt navigasyon

Liste, renkli kartların duvarına dönüşmemelidir. Aynı anda en fazla bir büyük vurgu kartı kullanın.

### AI ekranı

1. Kısa görev odaklı başlık
2. Konuşma/üretim alanı
3. Düzenlenebilir AI önerisi
4. Açık onay veya uygulama eylemi
5. Geri alma/düzeltme yolu

### İstatistik ekranı

- Önce tek ana içgörü, sonra destekleyici metrikler.
- Grafikler yalnızca renkle ayrılmaz; label veya pattern kullanılır.
- Kullanıcıyı suçlayan dil kullanılmaz.

### Ayarlar ve formlar

- Bölümler açık başlıklarla gruplandırılır.
- Satırlar minimum `56px` yüksekliğindedir.
- Açıklama gerekiyorsa label altında kısa ve düz metin kullanılır.
- Kaydetme davranışı otomatikse açık geri bildirim gösterilir.

## 9. Hareket

| Kullanım | Süre | Eğri/özellik |
|---|---:|---|
| Basma geri bildirimi | 120ms | scale `1 -> 0.97` |
| Navigasyon seçimi | 180ms | `easeOutCubic` |
| Standart görünürlük/geçiş | 160–220ms | `easeOut` |
| Sheet/modal | 220–300ms | platform uyumlu |

Kurallar:

- Hareket kullanıcı eyleminden sonra başlamalıdır.
- Sürekli animasyon yalnızca aktif AI dinleme/üretim gibi canlı durumu temsil eder.
- `MediaQuery.disableAnimations` desteklenir; AI animasyonu azaltılmış harekette statik bir anlamlı kare gösterir.
- Aynı ekranda birden fazla sonsuz animasyon çalıştırılmaz.
- Confetti yalnızca gerçek ve seyrek başarılarda kullanılır.

## 10. Erişilebilirlik

- Normal metin için hedef kontrast en az `4.5:1`; büyük metin ve büyük ikon için `3:1`.
- Minimum dokunma alanı `44×44px`.
- Eylem ikonlarında `tooltip` ve `Semantics` etiketi bulunur.
- Renk, durumun tek göstergesi değildir.
- Dinamik metin büyütmede içerik kesilmez veya üst üste binmez.
- Odak sırası görsel okuma sırasını takip eder.
- Form hatası alanla ilişkilendirilir ve nasıl düzeltileceğini söyler.
- Haptik geri bildirim görsel/metinsel geri bildirimin yerine geçmez.
- Azaltılmış hareket, koyu tema ve ekran okuyucu senaryoları test edilir.
- Alt navigasyon ve yüzen kontroller son liste öğesini örtmez.

## 11. İçerik ve mikro metin

- Ton kısa, sakin, cesaretlendirici ve yargısızdır.
- Kullanıcıya ne olacağını CTA üzerinde açıkça söyleyin.
- “Başarısız oldun” yerine “Bu görev tamamlanmadı” gibi tarafsız dil kullanın.
- AI dili öneri niteliğinde olmalı: “Şöyle bölebilirim” veya “Bunu plana ekleyelim mi?”
- Belirsiz etiketlerden kaçının: “Devam” yerine mümkünse “Planı oluştur”.
- Başlıklarda gereksiz ünlem ve tam büyük harf kullanmayın.
- Uzun açıklamaları ilk görünümde göstermeyin; progressive disclosure kullanın.

## 12. Responsive ve platform davranışı

- Ana hedef telefon portre görünümüdür; ekran genişliği boyunca `20px` marj korunur.
- Tabletlerde içerik sonsuza kadar genişlemez; okunabilir merkezi kolon veya iki sütun kullanılır.
- Safe area tüm sabit üst/alt kontrollerde uygulanır.
- Klavye açıldığında birincil alan ve gönderme kontrolü görünür kalır.
- iOS ve Android platform davranışları korunur; görsel dil ortak olsa da sistem geri hareketi ve erişilebilirlik beklentileri değiştirilmez.

## 13. Teknik kullanım

Yeni özellikler tasarım primitive'lerini şu barrel üzerinden almalıdır:

```dart
import 'package:florien/core/widgets/florien_ui.dart';
```

Öncelikli kaynaklar:

- Tema ve token'lar: `mobile/lib/core/theme/florien_theme.dart`
- Ortak export: `mobile/lib/core/widgets/florien_ui.dart`
- Butonlar: `mobile/lib/core/widgets/florien_buttons.dart`
- Kartlar: `mobile/lib/core/widgets/florien_card.dart`
- Alt navigasyon: `mobile/lib/core/widgets/florien_bottom_nav.dart`
- AI yüzeyleri: `mobile/lib/core/widgets/florien_ai.dart`
- AI hareketi: `mobile/lib/core/widgets/florien_ai_animation.dart`

### Uygulama kuralları

- Feature dosyalarında yeni sabit renk üretmek yerine `FlorienColors` veya `context.palette` kullanın.
- Dark mode destekleyen yüzeylerde doğrudan `Colors.white`/`Colors.black` kullanmayın.
- Padding ve radius için mümkün olduğunca Florien token'larını kullanın.
- Ortaklaşan ikinci kullanım görüldüğünde bileşeni `core/widgets` altına taşıyın.
- Var olan primitive'i feature içinde kopyalamayın.
- İşlevsel durumlar için `Theme.of(context)` ve Material state'lerinden yararlanın.

## 14. Yap / yapma

### Yap

- Tek güçlü CTA ve açık içerik hiyerarşisi kur.
- Nötr yüzeyleri baskın, pastelleri destekleyici kullan.
- Büyük radius ve ince koyu konturu tutarlı uygula.
- AI alanlarını aynı gradyan ve hareket diliyle işaretle.
- Her etkileşim için yükleme, başarı, hata ve devre dışı durumunu düşün.
- Uzun içerikte navigasyon ve safe area boşluklarını test et.

### Yapma

- Aynı ekranda birden fazla sarı ana buton kullanma.
- Her karta farklı pastel renk vererek gökkuşağı görünümü oluşturma.
- Gölge, blur, cam efekti ve kalın konturu aynı bileşende birleştirme.
- Yeni bir ikon ailesini tek bir ekran için ekleme.
- Metni görsel varlığın içine gömme.
- Yalnızca renk değişimiyle durum anlatma.
- Kaynak logoyu veya AI varlığını kodla yaklaşık olarak yeniden çizme.

## 15. Tasarım inceleme kontrol listesi

Yeni ekran tamamlanmadan önce:

- [ ] Ekranda tek bir ana eylem var.
- [ ] Renkler yalnızca Florien token'larından geliyor.
- [ ] Manrope ve tanımlı text style'lar kullanılıyor.
- [ ] Yatay ekran marjı ve bölüm aralıkları token'larla uyumlu.
- [ ] Kart, buton ve input'lar ortak primitive'leri kullanıyor.
- [ ] Dokunma hedefleri en az `44×44px`.
- [ ] Light ve dark theme kontrol edildi.
- [ ] Büyük metin ölçeğinde taşma yok.
- [ ] VoiceOver/TalkBack label'ları anlamlı.
- [ ] Renk dışında ikinci bir durum göstergesi var.
- [ ] Boş, yükleniyor, hata ve başarı durumları tasarlandı.
- [ ] Yüzen navigasyon son içeriği örtmüyor.
- [ ] Hareket azaltma ayarında deneyim anlamını koruyor.

## 16. Belgenin güncellenmesi

`DESIGN.md` niyeti ve kullanım kurallarını; `florien_theme.dart` ise gerçek teknik değerleri tanımlar. Token değiştiğinde önce tema güncellenir, ardından bu belge aynı değişiklik içinde senkronize edilir. Yeni bir görsel kalıp kalıcı hale gelmeden önce en az iki gerçek kullanımda doğrulanmalıdır.
