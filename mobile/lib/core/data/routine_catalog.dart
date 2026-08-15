import 'package:florien/core/models/models.dart';

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

const routineThemes = [
  RoutineTheme(
    name: 'Güne başla',
    description: 'Sabaha yumuşak bir başlangıç',
    icon: 'breakfast',
    color: '#F2BC52',
    tasks: [
      RoutinePresetTask(
        title: 'Kahvaltı yap',
        description: 'Güne enerji verecek kısa bir kahvaltı hazırla.',
        durationMinutes: 20,
        period: DayPeriod.morning,
        icon: 'breakfast',
        subtasks: ['Bir şey seç', 'Hazırla', 'Masayı topla'],
      ),
      RoutinePresetTask(
        title: 'Hazırlan',
        description: 'Bugün için rahat ve yeterli şekilde hazırlan.',
        durationMinutes: 30,
        period: DayPeriod.morning,
        icon: 'clothes_shopping',
        subtasks: ['Kıyafet seç', 'Hazırlan', 'Çantanı kontrol et'],
      ),
      RoutinePresetTask(
        title: 'Gününü planla',
        description: 'Bugünün en önemli işlerini kısaca gözden geçir.',
        durationMinutes: 15,
        period: DayPeriod.morning,
        icon: 'appointment',
        subtasks: ['Takvimi aç', 'Üç öncelik belirle', 'İlk adımı seç'],
      ),
    ],
  ),
  RoutineTheme(
    name: 'Evi toparla',
    description: 'Küçük adımlarla ferah bir alan',
    icon: 'home',
    color: '#8FB6A0',
    tasks: [
      RoutinePresetTask(
        title: 'Mutfağı toparla',
        description: 'Mutfakta hızlı bir sıfırlama yap.',
        durationMinutes: 20,
        period: DayPeriod.daytime,
        icon: 'home',
        subtasks: ['Bulaşıkları topla', 'Tezgâhı sil', 'Çöpü kontrol et'],
      ),
      RoutinePresetTask(
        title: 'Çamaşırları hallet',
        description: 'Bir çamaşır döngüsünü başlat veya tamamla.',
        durationMinutes: 15,
        period: DayPeriod.daytime,
        icon: 'task',
        subtasks: ['Ayır', 'Makineyi çalıştır', 'Hatırlatıcı koy'],
      ),
      RoutinePresetTask(
        title: 'Odayı düzenle',
        description: 'Sadece görünür yüzeyleri toparla.',
        durationMinutes: 15,
        period: DayPeriod.daytime,
        icon: 'home',
        subtasks: ['Eşyaları yerine koy', 'Yatağı düzelt', 'Havalandır'],
      ),
    ],
  ),
  RoutineTheme(
    name: 'Kendine iyi bak',
    description: 'Temel ihtiyaçlarına yer aç',
    icon: 'health',
    color: '#AAA0BE',
    tasks: [
      RoutinePresetTask(
        title: 'İlaçlarını al',
        description: 'Günlük ilaç veya vitamin rutinini tamamla.',
        durationMinutes: 5,
        period: DayPeriod.morning,
        icon: 'medication',
        subtasks: ['İlacını hazırla', 'Su al', 'Aldığını işaretle'],
      ),
      RoutinePresetTask(
        title: 'Kısa yürüyüş yap',
        description: 'Biraz hareket edip nefes almak için dışarı çık.',
        durationMinutes: 25,
        period: DayPeriod.daytime,
        icon: 'walking',
        subtasks: ['Ayakkabılarını giy', 'Kısa bir rota seç', 'Su iç'],
      ),
      RoutinePresetTask(
        title: 'Duş al',
        description: 'Kısa bir bakım molası ver.',
        durationMinutes: 20,
        period: DayPeriod.evening,
        icon: 'health',
        subtasks: ['Havlu hazırla', 'Duş al', 'Rahat kıyafet giy'],
      ),
    ],
  ),
  RoutineTheme(
    name: 'Odak bloğu',
    description: 'Başlamak için hafif bir yapı',
    icon: 'timer',
    color: '#E98F82',
    tasks: [
      RoutinePresetTask(
        title: 'Odaklanma bloğu',
        description: 'Tek bir işe kısa ve korunaklı bir odak süresi ayır.',
        durationMinutes: 25,
        period: DayPeriod.daytime,
        icon: 'timer',
        subtasks: ['Tek işi seç', 'Dikkat dağıtanları kapat', 'Başla'],
      ),
      RoutinePresetTask(
        title: 'E-postaları gözden geçir',
        description: 'Sadece önemli iletileri ayıkla ve yanıtla.',
        durationMinutes: 20,
        period: DayPeriod.daytime,
        icon: 'email',
        subtasks: [
          'Gelen kutusunu aç',
          'Önemlileri ayır',
          'İki kısa yanıt yaz',
        ],
      ),
      RoutinePresetTask(
        title: 'Yarın için hazırlık yap',
        description: 'Yarının ilk adımını şimdiden kolaylaştır.',
        durationMinutes: 15,
        period: DayPeriod.evening,
        icon: 'appointment',
        subtasks: [
          'Takvimi kontrol et',
          'Gerekli eşyaları hazırla',
          'İlk işi not et',
        ],
      ),
    ],
  ),
];
