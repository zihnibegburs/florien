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
  required List<({String title, int minutes, String icon})> tasks,
}) => RoutineTheme(
  name: name,
  description: description,
  icon: icon,
  color: color,
  tasks: List.unmodifiable(
    tasks.map(
      (entry) => RoutinePresetTask(
        title: entry.title,
        description: '',
        durationMinutes: entry.minutes,
        period: period,
        icon: entry.icon,
        subtasks: List.unmodifiable(subtasks),
      ),
    ),
  ),
);

final List<RoutineTheme> routineThemes = List.unmodifiable([
  _routineTheme(
    name: 'Güne Güçlü Başla',
    description: 'Sabahı daha sakin ve yönü belli başlat',
    icon: 'stretching',
    color: '#FFF76A',
    period: DayPeriod.morning,
    subtasks: const [
      'Su iç ve bedenini uyandır',
      'Rutin için gerekenleri hazırla',
      'Başlangıcı tamamlayıp güne geç',
    ],
    tasks: const [
      (title: '10 Dakikada Ayağa Kalk', minutes: 10, icon: 'stretching'),
      (title: 'Sakin Sabah Başlangıcı', minutes: 20, icon: 'meditation'),
      (title: 'Enerjik Sabah Rutini', minutes: 30, icon: 'workout'),
      (title: 'Su ve Hareketle Uyan', minutes: 15, icon: 'drinks'),
      (title: 'Acele Etmeden Hazırlan', minutes: 30, icon: 'organizing'),
      (title: 'Kahvaltıyla Güç Topla', minutes: 25, icon: 'breakfast'),
      (title: 'Zihnini Boşaltarak Başla', minutes: 15, icon: 'note_taking'),
      (title: 'Günün Üç Önceliğini Seç', minutes: 15, icon: 'project'),
      (title: 'Telefonsuz İlk Yarım Saat', minutes: 30, icon: 'phone_call'),
      (title: 'Tam Sabah Rutini', minutes: 45, icon: 'stretching'),
    ],
  ),
  _routineTheme(
    name: 'Evden Hazır Çık',
    description: 'Çıkış öncesi telaşı küçük kontrollere böl',
    icon: 'home',
    color: '#BCEEFF',
    period: DayPeriod.morning,
    subtasks: const [
      'Yanına alacaklarını kontrol et',
      'Kendini ve gerekli eşyaları hazırla',
      'Çıkmadan önce son kontrolü yap',
    ],
    tasks: const [
      (title: '15 Dakikada Evden Çık', minutes: 15, icon: 'home'),
      (title: 'Çantanı Eksiksiz Hazırla', minutes: 15, icon: 'luggage'),
      (title: 'İşe Sakin Yetiş', minutes: 25, icon: 'work'),
      (title: 'Okula Hazır Çık', minutes: 25, icon: 'school'),
      (title: 'Spor Çantanı Topla', minutes: 20, icon: 'gym'),
      (title: 'Çocuklarla Evden Çık', minutes: 35, icon: 'childcare'),
      (title: 'Yağmurlu Güne Hazırlan', minutes: 20, icon: 'home'),
      (title: 'Seyahat Öncesi Son Kontrol', minutes: 30, icon: 'travel'),
      (title: 'Randevuya Hazır Git', minutes: 25, icon: 'appointment'),
      (title: 'Evi Güvenle Kapat', minutes: 15, icon: 'home'),
    ],
  ),
  _routineTheme(
    name: 'Harekete Geç',
    description: 'Başlangıç eşiğini küçült ve ilk adımı at',
    icon: 'project',
    color: '#DDFC83',
    period: DayPeriod.anytime,
    subtasks: const [
      'Tek ve küçük bir hedef seç',
      'İlk iki dakikalık adımı tamamla',
      'Devam etmek için sıradaki adımı belirle',
    ],
    tasks: const [
      (title: 'Sadece On Dakika Başla', minutes: 10, icon: 'project'),
      (title: 'Ertelediğin İşe İlk Adımı At', minutes: 15, icon: 'deadline'),
      (title: 'Zor İşi Yapılabilir Hale Getir', minutes: 20, icon: 'work'),
      (title: 'Çalışma Ortamını Kur', minutes: 15, icon: 'organizing'),
      (title: 'Kararsızlığı Tek Seçime İndir', minutes: 10, icon: 'research'),
      (title: 'Boş Sayfayı Doldurmaya Başla', minutes: 20, icon: 'writing'),
      (title: 'Enerjin Düşükken Harekete Geç', minutes: 15, icon: 'health'),
      (
        title: 'Başlangıç Engelini Ortadan Kaldır',
        minutes: 20,
        icon: 'project',
      ),
      (title: 'Yardım Alarak Başla', minutes: 15, icon: 'friends'),
      (title: 'İlk Parçayı Tamamla', minutes: 30, icon: 'project'),
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
      (title: '15 Dakikalık Hızlı Odak', minutes: 15, icon: 'work'),
      (title: '25 Dakikalık Tek İş', minutes: 25, icon: 'work'),
      (title: '45 Dakikalık Derin Odak', minutes: 45, icon: 'work'),
      (title: 'Kesintisiz Çalışma Saati', minutes: 60, icon: 'work'),
      (title: 'Gelen Kutusunu Bitir', minutes: 30, icon: 'email'),
      (title: 'Yazma Bloğu', minutes: 45, icon: 'writing'),
      (title: 'Okuma Bloğu', minutes: 30, icon: 'reading'),
      (title: 'Yaratıcı Üretim Bloğu', minutes: 60, icon: 'writing'),
      (title: 'Toplantıya Hazır Gir', minutes: 20, icon: 'meeting'),
      (title: 'Günün En Zor İşini Bitir', minutes: 45, icon: 'deadline'),
    ],
  ),
  _routineTheme(
    name: 'Bir Nefes Al',
    description: 'Kısa bir geçişle bedenine ve zihnine alan aç',
    icon: 'meditation',
    color: '#B8F2D0',
    period: DayPeriod.daytime,
    subtasks: const [
      'Bulunduğun işi güvenli bir yerde bırak',
      'Ekrandan ve bildirimlerden uzaklaş',
      'Nefesini ve bedenini kısa süre fark et',
    ],
    tasks: const [
      (title: 'On Dakikalık Sessiz Mola', minutes: 10, icon: 'meditation'),
      (title: 'Ekrandan Gözlerini Dinlendir', minutes: 10, icon: 'health'),
      (title: 'Kısa Açık Hava Molası', minutes: 15, icon: 'walking'),
      (title: 'Kahveni Sakince İç', minutes: 15, icon: 'coffee'),
      (title: 'Bedenini Aç ve Rahatla', minutes: 15, icon: 'stretching'),
      (title: 'Öğle Arasında Yenilen', minutes: 30, icon: 'lunch'),
      (title: 'Sessiz Bir Köşe Bul', minutes: 15, icon: 'meditation'),
      (title: 'Bir Şarkılık Mola', minutes: 10, icon: 'entertainment'),
      (title: 'Enerjini Toparla', minutes: 20, icon: 'health'),
      (title: 'İki İş Arasında Geçiş Yap', minutes: 10, icon: 'meditation'),
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
      (title: '10 Dakikalık Hızlı Toparlama', minutes: 10, icon: 'organizing'),
      (title: 'Mutfağı Temiz Bırak', minutes: 25, icon: 'dishes'),
      (title: 'Salonu Baştan Toparla', minutes: 25, icon: 'furniture'),
      (title: 'Yatak Odasını Ferahlat', minutes: 25, icon: 'furniture'),
      (title: 'Çalışma Masanı Toparla', minutes: 20, icon: 'organizing'),
      (title: 'Çamaşır Turunu Tamamla', minutes: 60, icon: 'laundry'),
      (title: 'Banyoyu Hızlıca Temizle', minutes: 30, icon: 'cleaning'),
      (title: 'Dolabın Bir Bölümünü Düzenle', minutes: 30, icon: 'organizing'),
      (title: 'Evin Girişini Toparla', minutes: 20, icon: 'home'),
      (title: 'Haftalık Ev Toparlaması', minutes: 75, icon: 'cleaning'),
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
      (title: 'Duş ve Baştan Aşağı Bakım', minutes: 30, icon: 'health'),
      (title: 'Saç ve Cilt Bakımı', minutes: 25, icon: 'health'),
      (title: 'Kendine Güzel Bir Öğün Hazırla', minutes: 30, icon: 'meal_prep'),
      (title: 'Açık Havada Yürü', minutes: 30, icon: 'walking'),
      (title: 'Bedenini Hareket Ettir', minutes: 20, icon: 'workout'),
      (title: 'İçindekileri Kağıda Dök', minutes: 15, icon: 'note_taking'),
      (title: 'Sevdiğin Birini Ara', minutes: 20, icon: 'phone_call'),
      (title: 'Ertelediğin Randevuyu Ayarla', minutes: 15, icon: 'appointment'),
      (title: 'Sessizce Dinlen', minutes: 20, icon: 'sleep'),
      (title: 'Sevdiğin Şeye Zaman Ayır', minutes: 30, icon: 'entertainment'),
    ],
  ),
  _routineTheme(
    name: 'Dijital Mola',
    description: 'Ekranla arana kısa ve bilinçli bir mesafe koy',
    icon: 'phone_call',
    color: '#BCEEFF',
    period: DayPeriod.anytime,
    subtasks: const [
      'Bildirimleri sessize al',
      'Telefonu görüş alanının dışına bırak',
      'Ekransız bir alternatif seç',
    ],
    tasks: const [
      (title: '30 Dakika Telefonsuz Kal', minutes: 30, icon: 'phone_call'),
      (title: 'Bir Saat Çevrimdışı Kal', minutes: 60, icon: 'phone_call'),
      (title: 'Gereksiz Bildirimleri Kapat', minutes: 20, icon: 'phone_call'),
      (title: 'Sosyal Medyaya Ara Ver', minutes: 30, icon: 'entertainment'),
      (title: 'Ekransız Bir Öğün', minutes: 30, icon: 'lunch'),
      (title: 'Telefonsuz Kısa Yürüyüş', minutes: 20, icon: 'walking'),
      (title: 'Ana Ekranını Sadeleştir', minutes: 20, icon: 'organizing'),
      (title: 'Uygulama Sürelerini Düzenle', minutes: 15, icon: 'organizing'),
      (title: 'Mesajlara Tek Seferde Bak', minutes: 20, icon: 'email'),
      (title: 'Ekransız Akşam Başlat', minutes: 60, icon: 'sleep'),
    ],
  ),
  _routineTheme(
    name: 'Kaldığın Yerden Devam Et',
    description: 'Bozulan planı suçluluk eklemeden yeniden kur',
    icon: 'project',
    color: '#DDFC83',
    period: DayPeriod.anytime,
    subtasks: const [
      'Şu anki durumu kısaca gözden geçir',
      'Planı tek yapılabilir işe küçült',
      'İlk geri dönüş adımını tamamla',
    ],
    tasks: const [
      (title: 'Plan Bozulduktan Sonra Geri Dön', minutes: 15, icon: 'project'),
      (title: 'Bir İşi Kaçırınca Devam Et', minutes: 10, icon: 'deadline'),
      (title: 'Öğleden Sonrayı Yeniden Kur', minutes: 20, icon: 'appointment'),
      (title: 'Dağınık Zihni Tek İşe İndir', minutes: 15, icon: 'therapy'),
      (title: 'Enerjin Düşünce Planı Küçült', minutes: 15, icon: 'health'),
      (title: 'Beklenmedik Bir İşten Sonra Dön', minutes: 10, icon: 'work'),
      (title: 'Yarım Kalan İşi Yeniden Aç', minutes: 15, icon: 'project'),
      (title: 'Kaçan Sabahı Geride Bırak', minutes: 10, icon: 'stretching'),
      (title: 'Yoğun Günün Kalanını Hafiflet', minutes: 20, icon: 'meditation'),
      (title: 'Bugünü Tek İşle Tamamla', minutes: 25, icon: 'work'),
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
      (title: 'On Dakikalık Gün Kapanışı', minutes: 10, icon: 'note_taking'),
      (title: 'Bugün Yaptıklarını Fark Et', minutes: 10, icon: 'note_taking'),
      (title: 'Kalan İşleri Yarına Taşı', minutes: 15, icon: 'appointment'),
      (title: 'Yarının Takvimini Kur', minutes: 15, icon: 'appointment'),
      (title: 'İş Gününü Geride Bırak', minutes: 15, icon: 'work'),
      (title: 'Aklındakileri Kağıda Bırak', minutes: 15, icon: 'writing'),
      (title: 'Günün Harcamalarını Kaydet', minutes: 15, icon: 'finance'),
      (title: 'Sabahı Şimdiden Kolaylaştır', minutes: 20, icon: 'breakfast'),
      (title: 'Evi Akşama Toparla', minutes: 20, icon: 'cleaning'),
      (title: 'Gününü Üç Satırda Bitir', minutes: 10, icon: 'writing'),
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
      (title: '20 Dakikada Uykuya Hazırlan', minutes: 20, icon: 'sleep'),
      (title: 'Işıkları Azalt ve Yavaşla', minutes: 15, icon: 'sleep'),
      (title: 'Gece Bakımını Tamamla', minutes: 20, icon: 'health'),
      (title: 'Yatak Odanı Uykuya Hazırla', minutes: 15, icon: 'sleep'),
      (
        title: 'Zihnindekileri Yatağın Dışında Bırak',
        minutes: 15,
        icon: 'note_taking',
      ),
      (title: 'Telefonu Bırakıp Geceye Geç', minutes: 30, icon: 'phone_call'),
      (title: 'Kitapla Günü Bitir', minutes: 30, icon: 'reading'),
      (title: 'Bedenini Gevşet', minutes: 20, icon: 'stretching'),
      (title: 'Erken Uykuya Geçiş', minutes: 45, icon: 'sleep'),
      (title: 'Tam Gece Rutini', minutes: 60, icon: 'sleep'),
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
      (title: 'Haftanın Üç Önceliğini Kur', minutes: 20, icon: 'project'),
      (title: 'Takvimini Baştan Düzenle', minutes: 30, icon: 'appointment'),
      (title: 'Yoğun Günleri Hafiflet', minutes: 25, icon: 'meditation'),
      (title: 'Yemek ve Alışveriş Planı', minutes: 45, icon: 'groceries'),
      (title: 'Ev İşlerini Haftaya Yay', minutes: 30, icon: 'cleaning'),
      (title: 'Hareket Günlerini Seç', minutes: 20, icon: 'workout'),
      (title: 'Sosyal Planlarını Yerleştir', minutes: 20, icon: 'friends'),
      (title: 'Para İşlerini Gözden Geçir', minutes: 30, icon: 'finance'),
      (title: 'Boş Zamanını Koru', minutes: 20, icon: 'entertainment'),
      (
        title: 'Pazar Akşamı Haftaya Hazırlan',
        minutes: 45,
        icon: 'appointment',
      ),
    ],
  ),
]);
