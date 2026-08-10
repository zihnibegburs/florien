import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/theme/florien_theme.dart';

List<RoutineTemplate> routineTemplatesFor(String lang) {
  final isTr = lang == 'tr';
  return [
    RoutineTemplate(
      id: 'morning',
      name: isTr ? 'Sabah rutini' : 'Morning routine',
      icon: 'free_breakfast',
      color: FlorienColors.taskColors[2],
      steps: [
        RoutineTemplateStep(
          title: isTr ? 'Yataktan kalk' : 'Get out of bed',
          durationMinutes: 5,
          color: FlorienColors.taskColors[2],
          icon: 'bedtime',
        ),
        RoutineTemplateStep(
          title: isTr ? 'Yüzünü yıka' : 'Wash face',
          durationMinutes: 5,
          color: FlorienColors.taskColors[4],
        ),
        RoutineTemplateStep(
          title: isTr ? 'Kahvaltı' : 'Breakfast',
          durationMinutes: 20,
          color: FlorienColors.taskColors[1],
          icon: 'free_breakfast',
        ),
        RoutineTemplateStep(
          title: isTr ? 'Güne hazırlık' : 'Plan the day',
          durationMinutes: 10,
          color: FlorienColors.taskColors[0],
          icon: 'lightbulb',
        ),
      ],
    ),
    RoutineTemplate(
      id: 'work_start',
      name: isTr ? 'İşe başlama' : 'Work start',
      icon: 'work',
      color: FlorienColors.taskColors[0],
      steps: [
        RoutineTemplateStep(
          title: isTr ? 'Masa düzeni' : 'Tidy desk',
          durationMinutes: 5,
          color: FlorienColors.taskColors[3],
          icon: 'cleaning',
        ),
        RoutineTemplateStep(
          title: isTr ? 'E-postaları kontrol et' : 'Check emails',
          durationMinutes: 15,
          color: FlorienColors.taskColors[0],
          icon: 'email',
        ),
        RoutineTemplateStep(
          title: isTr ? 'En önemli görev' : 'Top priority task',
          durationMinutes: 45,
          color: FlorienColors.taskColors[0],
          icon: 'timer',
        ),
      ],
    ),
    RoutineTemplate(
      id: 'bedtime',
      name: isTr ? 'Uyku hazırlığı' : 'Bedtime prep',
      icon: 'bedtime',
      color: FlorienColors.taskColors[5],
      steps: [
        RoutineTemplateStep(
          title: isTr ? 'Ekranları kapat' : 'Screen off',
          durationMinutes: 5,
          color: FlorienColors.taskColors[5],
        ),
        RoutineTemplateStep(
          title: isTr ? 'Diş fırçala' : 'Brush teeth',
          durationMinutes: 5,
          color: FlorienColors.taskColors[4],
        ),
        RoutineTemplateStep(
          title: isTr ? 'Yarını planla' : 'Plan tomorrow',
          durationMinutes: 10,
          color: FlorienColors.taskColors[0],
        ),
        RoutineTemplateStep(
          title: isTr ? 'Rahatlama' : 'Wind down',
          durationMinutes: 15,
          color: FlorienColors.taskColors[5],
          icon: 'self_improvement',
        ),
      ],
    ),
  ];
}

List<MedicationPreset> medicationPresetsFor(String lang) {
  final isTr = lang == 'tr';
  return [
    MedicationPreset(
      title: isTr ? 'İlaç al' : 'Take medication',
      durationMinutes: 2,
      color: '#E74C3C',
      icon: 'medication',
    ),
    MedicationPreset(
      title: isTr ? 'Vitamin' : 'Vitamins',
      durationMinutes: 2,
      color: '#F39C12',
      icon: 'medication',
    ),
    MedicationPreset(
      title: isTr ? 'Su iç' : 'Drink water',
      durationMinutes: 2,
      color: '#3498DB',
      icon: 'water_drop',
    ),
  ];
}
