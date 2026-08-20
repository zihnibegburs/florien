import 'package:florien/core/models/models.dart';

const readyRoutineTaskColor = '#C4B5FD';

class RoutinePresetTask {
  const RoutinePresetTask({
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.period,
    required this.icon,
    required this.subtasks,
  });

  final String title;
  final String description;
  final int durationMinutes;
  final DayPeriod period;
  final String icon;
  final List<String> subtasks;
}

class RoutineTheme {
  const RoutineTheme({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.tasks,
  });

  final String name;
  final String description;
  final String icon;
  final String color;
  final List<RoutinePresetTask> tasks;
}

RoutineTheme _routineTheme({
  required String name,
  required String description,
  required String icon,
  required String color,
  required DayPeriod period,
  required List<String> subtasks,
  required List<({String title, int minutes})> tasks,
}) => RoutineTheme(
  name: name,
  description: description,
  icon: icon,
  color: color,
  tasks: List.unmodifiable(
    tasks.map(
      (entry) => RoutinePresetTask(
        title: entry.title,
        description: '${entry.title} için hazır ve düzenlenebilir bir rutin.',
        durationMinutes: entry.minutes,
        period: period,
        icon: icon,
        subtasks: List.unmodifiable(subtasks),
      ),
    ),
  ),
);

final List<RoutineTheme> routineThemes = List.unmodifiable([
  _routineTheme(
    name: 'Güne Güçlü Başla',
    description: 'Sabahı daha sakin ve yönü belli başlat',
    icon: 'breakfast',
    color: '#FFF76A',
    period: DayPeriod.morning,
    subtasks: const [
      'Su iç ve bedenini uyandır',
      'Rutin için gerekenleri hazırla',
      'Başlangıcı tamamlayıp güne geç',
    ],
    tasks: const [
      (title: '10 Dakikada Ayağa Kalk', minutes: 10),
      (title: 'Sakin Sabah Başlangıcı', minutes: 20),
      (title: 'Enerjik Sabah Rutini', minutes: 30),
      (title: 'Su ve Hareketle Uyan', minutes: 15),
      (title: 'Acele Etmeden Hazırlan', minutes: 30),
      (title: 'Kahvaltıyla Güç Topla', minutes: 25),
      (title: 'Zihnini Boşaltarak Başla', minutes: 15),
      (title: 'Günün Üç Önceliğini Seç', minutes: 15),
      (title: 'Telefonsuz İlk Yarım Saat', minutes: 30),
      (title: 'Tam Sabah Rutini', minutes: 45),
    ],
  ),
  _routineTheme(
    name: 'Evden Hazır Çık',
    description: 'Çıkış öncesi telaşı küçük kontrollere böl',
    icon: 'travel',
    color: '#BCEEFF',
    period: DayPeriod.morning,
    subtasks: const [
      'Yanına alacaklarını kontrol et',
      'Kendini ve gerekli eşyaları hazırla',
      'Çıkmadan önce son kontrolü yap',
    ],
    tasks: const [
      (title: '15 Dakikada Evden Çık', minutes: 15),
      (title: 'Çantanı Eksiksiz Hazırla', minutes: 15),
      (title: 'İşe Sakin Yetiş', minutes: 25),
      (title: 'Okula Hazır Çık', minutes: 25),
      (title: 'Spor Çantanı Topla', minutes: 20),
      (title: 'Çocuklarla Evden Çık', minutes: 35),
      (title: 'Yağmurlu Güne Hazırlan', minutes: 20),
      (title: 'Seyahat Öncesi Son Kontrol', minutes: 30),
      (title: 'Randevuya Hazır Git', minutes: 25),
      (title: 'Evi Güvenle Kapat', minutes: 15),
    ],
  ),
  _routineTheme(
    name: 'Harekete Geç',
    description: 'Başlangıç eşiğini küçült ve ilk adımı at',
    icon: 'other',
    color: '#DDFC83',
    period: DayPeriod.anytime,
    subtasks: const [
      'Tek ve küçük bir hedef seç',
      'İlk iki dakikalık adımı tamamla',
      'Devam etmek için sıradaki adımı belirle',
    ],
    tasks: const [
      (title: 'Sadece On Dakika Başla', minutes: 10),
      (title: 'Ertelediğin İşe İlk Adımı At', minutes: 15),
      (title: 'Zor İşi Yapılabilir Hale Getir', minutes: 20),
      (title: 'Çalışma Ortamını Kur', minutes: 15),
      (title: 'Kararsızlığı Tek Seçime İndir', minutes: 10),
      (title: 'Boş Sayfayı Doldurmaya Başla', minutes: 20),
      (title: 'Enerjin Düşükken Harekete Geç', minutes: 15),
      (title: 'Başlangıç Engelini Ortadan Kaldır', minutes: 20),
      (title: 'Yardım Alarak Başla', minutes: 15),
      (title: 'İlk Parçayı Tamamla', minutes: 30),
    ],
  ),
  _routineTheme(
    name: 'Odağını Bul',
    description: 'Tek işe ayrılmış, korunaklı bir çalışma alanı aç',
    icon: 'work',
    color: '#C4B5FD',
    period: DayPeriod.daytime,
    subtasks: const [
      'Odaklanacağın tek işi seç',
      'Dikkat dağıtıcıları kapat',
      'Süre bitene kadar yalnızca o işe dön',
    ],
    tasks: const [
      (title: '15 Dakikalık Hızlı Odak', minutes: 15),
      (title: '25 Dakikalık Tek İş', minutes: 25),
      (title: '45 Dakikalık Derin Odak', minutes: 45),
      (title: 'Kesintisiz Çalışma Saati', minutes: 60),
      (title: 'Gelen Kutusunu Bitir', minutes: 30),
      (title: 'Yazma Bloğu', minutes: 45),
      (title: 'Okuma Bloğu', minutes: 30),
      (title: 'Yaratıcı Üretim Bloğu', minutes: 60),
      (title: 'Toplantıya Hazır Gir', minutes: 20),
      (title: 'Günün En Zor İşini Bitir', minutes: 45),
    ],
  ),
  _routineTheme(
    name: 'Bir Nefes Al',
    description: 'Kısa bir geçişle bedenine ve zihnine alan aç',
    icon: 'coffee',
    color: '#B8F2D0',
    period: DayPeriod.daytime,
    subtasks: const [
      'Bulunduğun işi güvenli bir yerde bırak',
      'Ekrandan ve bildirimlerden uzaklaş',
      'Nefesini ve bedenini kısa süre fark et',
    ],
    tasks: const [
      (title: 'On Dakikalık Sessiz Mola', minutes: 10),
      (title: 'Ekrandan Gözlerini Dinlendir', minutes: 10),
      (title: 'Kısa Açık Hava Molası', minutes: 15),
      (title: 'Kahveni Sakince İç', minutes: 15),
      (title: 'Bedenini Aç ve Rahatla', minutes: 15),
      (title: 'Öğle Arasında Yenilen', minutes: 30),
      (title: 'Sessiz Bir Köşe Bul', minutes: 15),
      (title: 'Bir Şarkılık Mola', minutes: 10),
      (title: 'Enerjini Toparla', minutes: 20),
      (title: 'İki İş Arasında Geçiş Yap', minutes: 10),
    ],
  ),
  _routineTheme(
    name: 'Alanını Ferahlat',
    description: 'Görünür karmaşayı küçük alanlar halinde azalt',
    icon: 'cleaning',
    color: '#FFE0B2',
    period: DayPeriod.daytime,
    subtasks: const [
      'Tek bir alan seç',
      'Çöpü ve yerine ait olmayanları ayır',
      'Yüzeyi temizleyip son kontrolü yap',
    ],
    tasks: const [
      (title: '10 Dakikalık Hızlı Toparlama', minutes: 10),
      (title: 'Mutfağı Temiz Bırak', minutes: 25),
      (title: 'Salonu Baştan Toparla', minutes: 25),
      (title: 'Yatak Odasını Ferahlat', minutes: 25),
      (title: 'Çalışma Masanı Toparla', minutes: 20),
      (title: 'Çamaşır Turunu Tamamla', minutes: 60),
      (title: 'Banyoyu Hızlıca Temizle', minutes: 30),
      (title: 'Dolabın Bir Bölümünü Düzenle', minutes: 30),
      (title: 'Evin Girişini Toparla', minutes: 20),
      (title: 'Haftalık Ev Toparlaması', minutes: 75),
    ],
  ),
  _routineTheme(
    name: 'Kendine Dön',
    description: 'Temel ihtiyaçlarını ve iyi oluşunu öne al',
    icon: 'health',
    color: '#FFD6E7',
    period: DayPeriod.anytime,
    subtasks: const [
      'Şu anki ihtiyacını fark et',
      'Gerekli ortamı ve malzemeleri hazırla',
      'Kendine ayırdığın zamanı tamamla',
    ],
    tasks: const [
      (title: 'Duş ve Baştan Aşağı Bakım', minutes: 30),
      (title: 'Saç ve Cilt Bakımı', minutes: 25),
      (title: 'Kendine Güzel Bir Öğün Hazırla', minutes: 30),
      (title: 'Açık Havada Yürü', minutes: 30),
      (title: 'Bedenini Hareket Ettir', minutes: 20),
      (title: 'İçindekileri Kağıda Dök', minutes: 15),
      (title: 'Sevdiğin Birini Ara', minutes: 20),
      (title: 'Ertelediğin Randevuyu Ayarla', minutes: 15),
      (title: 'Sessizce Dinlen', minutes: 20),
      (title: 'Sevdiğin Şeye Zaman Ayır', minutes: 30),
    ],
  ),
  _routineTheme(
    name: 'Dijital Mola',
    description: 'Ekranla arana kısa ve bilinçli bir mesafe koy',
    icon: 'other',
    color: '#BCEEFF',
    period: DayPeriod.anytime,
    subtasks: const [
      'Bildirimleri sessize al',
      'Telefonu görüş alanının dışına bırak',
      'Ekransız bir alternatif seç',
    ],
    tasks: const [
      (title: '30 Dakika Telefonsuz Kal', minutes: 30),
      (title: 'Bir Saat Çevrimdışı Kal', minutes: 60),
      (title: 'Gereksiz Bildirimleri Kapat', minutes: 20),
      (title: 'Sosyal Medyaya Ara Ver', minutes: 30),
      (title: 'Ekransız Bir Öğün', minutes: 30),
      (title: 'Telefonsuz Kısa Yürüyüş', minutes: 20),
      (title: 'Ana Ekranını Sadeleştir', minutes: 20),
      (title: 'Uygulama Sürelerini Düzenle', minutes: 15),
      (title: 'Mesajlara Tek Seferde Bak', minutes: 20),
      (title: 'Ekransız Akşam Başlat', minutes: 60),
    ],
  ),
  _routineTheme(
    name: 'Kaldığın Yerden Devam Et',
    description: 'Bozulan planı suçluluk eklemeden yeniden kur',
    icon: 'appointment',
    color: '#DDFC83',
    period: DayPeriod.anytime,
    subtasks: const [
      'Şu anki durumu kısaca gözden geçir',
      'Planı tek yapılabilir işe küçült',
      'İlk geri dönüş adımını tamamla',
    ],
    tasks: const [
      (title: 'Plan Bozulduktan Sonra Geri Dön', minutes: 15),
      (title: 'Bir İşi Kaçırınca Devam Et', minutes: 10),
      (title: 'Öğleden Sonrayı Yeniden Kur', minutes: 20),
      (title: 'Dağınık Zihni Tek İşe İndir', minutes: 15),
      (title: 'Enerjin Düşünce Planı Küçült', minutes: 15),
      (title: 'Beklenmedik Bir İşten Sonra Dön', minutes: 10),
      (title: 'Yarım Kalan İşi Yeniden Aç', minutes: 15),
      (title: 'Kaçan Sabahı Geride Bırak', minutes: 10),
      (title: 'Yoğun Günün Kalanını Hafiflet', minutes: 20),
      (title: 'Bugünü Tek İşle Tamamla', minutes: 25),
    ],
  ),
  _routineTheme(
    name: 'Günü Tamamla',
    description: 'Açık döngüleri kapat ve yarına yer aç',
    icon: 'note_taking',
    color: '#C4B5FD',
    period: DayPeriod.evening,
    subtasks: const [
      'Bugün tamamlananları fark et',
      'Açık işleri not et veya yeniden planla',
      'Yarının ilk adımını hazır bırak',
    ],
    tasks: const [
      (title: 'On Dakikalık Gün Kapanışı', minutes: 10),
      (title: 'Bugün Yaptıklarını Fark Et', minutes: 10),
      (title: 'Kalan İşleri Yarına Taşı', minutes: 15),
      (title: 'Yarının Takvimini Kur', minutes: 15),
      (title: 'İş Gününü Geride Bırak', minutes: 15),
      (title: 'Aklındakileri Kağıda Bırak', minutes: 15),
      (title: 'Günün Harcamalarını Kaydet', minutes: 15),
      (title: 'Sabahı Şimdiden Kolaylaştır', minutes: 20),
      (title: 'Evi Akşama Toparla', minutes: 20),
      (title: 'Gününü Üç Satırda Bitir', minutes: 10),
    ],
  ),
  _routineTheme(
    name: 'Uykuya Hazırlan',
    description: 'Işığı, bedeni ve zihni geceye geçir',
    icon: 'sleep',
    color: '#D1C4E9',
    period: DayPeriod.evening,
    subtasks: const [
      'Işığı ve ekranları azalt',
      'Gece bakımını tamamla',
      'Yatak odasını sakin ve hazır bırak',
    ],
    tasks: const [
      (title: '20 Dakikada Uykuya Hazırlan', minutes: 20),
      (title: 'Işıkları Azalt ve Yavaşla', minutes: 15),
      (title: 'Gece Bakımını Tamamla', minutes: 20),
      (title: 'Yatak Odanı Uykuya Hazırla', minutes: 15),
      (title: 'Zihnindekileri Yatağın Dışında Bırak', minutes: 15),
      (title: 'Telefonu Bırakıp Geceye Geç', minutes: 30),
      (title: 'Kitapla Günü Bitir', minutes: 30),
      (title: 'Bedenini Gevşet', minutes: 20),
      (title: 'Erken Uykuya Geçiş', minutes: 45),
      (title: 'Tam Gece Rutini', minutes: 60),
    ],
  ),
  _routineTheme(
    name: 'Haftanı Hafiflet',
    description: 'Haftanın yükünü önceden gör ve daha dengeli dağıt',
    icon: 'appointment',
    color: '#B8F2D0',
    period: DayPeriod.daytime,
    subtasks: const [
      'Haftanın sabitlerini takvime yerleştir',
      'Üç ana önceliği seç',
      'Dinlenme ve boş zaman için alan koru',
    ],
    tasks: const [
      (title: 'Haftanın Üç Önceliğini Kur', minutes: 20),
      (title: 'Takvimini Baştan Düzenle', minutes: 30),
      (title: 'Yoğun Günleri Hafiflet', minutes: 25),
      (title: 'Yemek ve Alışveriş Planı', minutes: 45),
      (title: 'Ev İşlerini Haftaya Yay', minutes: 30),
      (title: 'Hareket Günlerini Seç', minutes: 20),
      (title: 'Sosyal Planlarını Yerleştir', minutes: 20),
      (title: 'Para İşlerini Gözden Geçir', minutes: 30),
      (title: 'Boş Zamanını Koru', minutes: 20),
      (title: 'Pazar Akşamı Haftaya Hazırlan', minutes: 45),
    ],
  ),
]);
