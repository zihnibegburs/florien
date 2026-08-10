import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';

const supportedLanguageCodes = ['en', 'tr', 'es', 'fr', 'de'];

final appLanguageProvider = AsyncNotifierProvider<AppLanguageNotifier, String>(AppLanguageNotifier.new);

class AppLanguageNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return ref.read(settingsStorageProvider).getLanguage();
  }

  Future<void> setLanguage(String code) async {
    await ref.read(settingsStorageProvider).setLanguage(code);
    state = AsyncData(code);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ref.read(userProfileServiceProvider).patchSettings(uid, {'language': code});
      } catch (_) {}
    }
  }
}

String l10n(String lang, Map<String, String> translations) {
  return translations[lang] ?? translations['en']!;
}

String dateLocaleFor(String lang) => switch (lang) {
      'tr' => 'tr_TR',
      'es' => 'es_ES',
      'fr' => 'fr_FR',
      'de' => 'de_DE',
      _ => 'en_US',
    };

class S {
  S(this.lang);

  final String lang;

  bool get isEn => lang == 'en';

  // Profile & settings
  String get profile => l10n(lang, _m(en: 'Profile', tr: 'Profil', es: 'Perfil', fr: 'Profil', de: 'Profil'));
  String get editProfile =>
      l10n(lang, _m(en: 'Edit profile', tr: 'Profili düzenle', es: 'Editar perfil', fr: 'Modifier le profil', de: 'Profil bearbeiten'));
  String get displayName =>
      l10n(lang, _m(en: 'Display name', tr: 'Görünen ad', es: 'Nombre visible', fr: 'Nom affiché', de: 'Anzeigename'));
  String get avatarColor =>
      l10n(lang, _m(en: 'Avatar color', tr: 'Avatar rengi', es: 'Color del avatar', fr: 'Couleur de l\'avatar', de: 'Avatar-Farbe'));
  String get language => l10n(lang, _m(en: 'Language', tr: 'Dil', es: 'Idioma', fr: 'Langue', de: 'Sprache'));
  String get appearance =>
      l10n(lang, _m(en: 'Appearance', tr: 'Görünüm', es: 'Apariencia', fr: 'Apparence', de: 'Erscheinungsbild'));
  String get themeSystem =>
      l10n(lang, _m(en: 'System', tr: 'Sistem', es: 'Sistema', fr: 'Système', de: 'System'));
  String get themeLight =>
      l10n(lang, _m(en: 'Light', tr: 'Açık', es: 'Claro', fr: 'Clair', de: 'Hell'));
  String get themeDark =>
      l10n(lang, _m(en: 'Dark', tr: 'Koyu', es: 'Oscuro', fr: 'Sombre', de: 'Dunkel'));
  String themeModeLabel(AppThemePreference pref) => switch (pref) {
        AppThemePreference.system => themeSystem,
        AppThemePreference.light => themeLight,
        AppThemePreference.dark => themeDark,
      };
  String get preferences =>
      l10n(lang, _m(en: 'Preferences', tr: 'Tercihler', es: 'Preferencias', fr: 'Préférences', de: 'Einstellungen'));
  String get account => l10n(lang, _m(en: 'Account', tr: 'Hesap', es: 'Cuenta', fr: 'Compte', de: 'Konto'));
  String get logout => l10n(lang, _m(en: 'Log out', tr: 'Çıkış yap', es: 'Cerrar sesión', fr: 'Se déconnecter', de: 'Abmelden'));
  String get save => l10n(lang, _m(en: 'Save', tr: 'Kaydet', es: 'Guardar', fr: 'Enregistrer', de: 'Speichern'));
  String get saving => l10n(lang, _m(en: 'Saving...', tr: 'Kaydediliyor...', es: 'Guardando...', fr: 'Enregistrement...', de: 'Speichern...'));
  String get cancel => l10n(lang, _m(en: 'Cancel', tr: 'İptal', es: 'Cancelar', fr: 'Annuler', de: 'Abbrechen'));
  String get version => l10n(lang, _m(en: 'Version', tr: 'Sürüm', es: 'Versión', fr: 'Version', de: 'Version'));
  String get notifications =>
      l10n(lang, _m(en: 'Notifications', tr: 'Bildirimler', es: 'Notificaciones', fr: 'Notifications', de: 'Benachrichtigungen'));
  String get comingSoon =>
      l10n(lang, _m(en: 'Coming soon', tr: 'Yakında', es: 'Próximamente', fr: 'Bientôt disponible', de: 'Demnächst'));
  String get profileUpdated =>
      l10n(lang, _m(en: 'Profile updated', tr: 'Profil güncellendi', es: 'Perfil actualizado', fr: 'Profil mis à jour', de: 'Profil aktualisiert'));
  String get integrations =>
      l10n(lang, _m(en: 'Integrations', tr: 'Entegrasyonlar', es: 'Integraciones', fr: 'Intégrations', de: 'Integrationen'));
  String get calendarImport =>
      l10n(lang, _m(en: 'Import from calendar', tr: 'Takvimden aktar', es: 'Importar del calendario', fr: 'Importer du calendrier', de: 'Aus Kalender importieren'));
  String get calendarImportSubtitle => l10n(lang, _m(
        en: 'Turn calendar events into Florien tasks for your daily plan.',
        tr: 'Takvim etkinliklerini günlük planına görev olarak ekle.',
        es: 'Convierte eventos del calendario en tareas de Florien.',
        fr: 'Transformez les événements du calendrier en tâches Florien.',
        de: 'Kalendertermine als Florien-Aufgaben in deinen Tagesplan übernehmen.',
      ));
  String get calendarImportTitle =>
      l10n(lang, _m(en: 'Calendar import', tr: 'Takvim aktarma', es: 'Importar calendario', fr: 'Import calendrier', de: 'Kalenderimport'));
  String get calendarImportPermissionDenied => l10n(lang, _m(
        en: 'Calendar access is required to import events.',
        tr: 'Etkinlikleri aktarmak için takvim erişimi gerekiyor.',
        es: 'Se necesita acceso al calendario para importar eventos.',
        fr: 'L\'accès au calendrier est requis pour importer les événements.',
        de: 'Kalenderzugriff ist erforderlich, um Termine zu importieren.',
      ));
  String get calendarImportSelectCalendars => l10n(lang, _m(
        en: 'Select calendars',
        tr: 'Takvimleri seç',
        es: 'Seleccionar calendarios',
        fr: 'Sélectionner les calendriers',
        de: 'Kalender auswählen',
      ));
  String get calendarImportDateRange =>
      l10n(lang, _m(en: 'Date range', tr: 'Tarih aralığı', es: 'Rango de fechas', fr: 'Période', de: 'Zeitraum'));
  String get calendarImportToday =>
      l10n(lang, _m(en: 'Today', tr: 'Bugün', es: 'Hoy', fr: 'Aujourd\'hui', de: 'Heute'));
  String get calendarImportThisWeek =>
      l10n(lang, _m(en: 'This week', tr: 'Bu hafta', es: 'Esta semana', fr: 'Cette semaine', de: 'Diese Woche'));
  String get calendarImportNext7Days => l10n(lang, _m(
        en: 'Next 7 days',
        tr: 'Sonraki 7 gün',
        es: 'Próximos 7 días',
        fr: '7 prochains jours',
        de: 'Nächste 7 Tage',
      ));
  String get calendarImportPreview =>
      l10n(lang, _m(en: 'Events to import', tr: 'Aktarılacak etkinlikler', es: 'Eventos a importar', fr: 'Événements à importer', de: 'Zu importierende Termine'));
  String get calendarImportNoEvents => l10n(lang, _m(
        en: 'No new events found in this range.',
        tr: 'Bu aralıkta aktarılacak yeni etkinlik bulunamadı.',
        es: 'No hay eventos nuevos en este rango.',
        fr: 'Aucun nouvel événement dans cette période.',
        de: 'Keine neuen Termine in diesem Zeitraum.',
      ));
  String get calendarImportNoCalendars => l10n(lang, _m(
        en: 'No calendars found on this device.',
        tr: 'Bu cihazda takvim bulunamadı.',
        es: 'No se encontraron calendarios en este dispositivo.',
        fr: 'Aucun calendrier trouvé sur cet appareil.',
        de: 'Keine Kalender auf diesem Gerät gefunden.',
      ));
  String calendarImportButton(int count) => l10n(lang, _m(
        en: 'Import $count events',
        tr: '$count etkinliği aktar',
        es: 'Importar $count eventos',
        fr: 'Importer $count événements',
        de: '$count Termine importieren',
      ));
  String calendarImportSuccess(int count) => l10n(lang, _m(
        en: '$count calendar events imported ✨',
        tr: '$count takvim etkinliği aktarıldı ✨',
        es: '$count eventos del calendario importados ✨',
        fr: '$count événements importés ✨',
        de: '$count Kalendertermine importiert ✨',
      ));
  String get calendarImportUnavailable => l10n(lang, _m(
        en: 'Calendar import is available on iOS and Android only.',
        tr: 'Takvim aktarma yalnızca iOS ve Android\'de kullanılabilir.',
        es: 'La importación del calendario solo está disponible en iOS y Android.',
        fr: 'L\'import calendrier est disponible uniquement sur iOS et Android.',
        de: 'Kalenderimport ist nur auf iOS und Android verfügbar.',
      ));
  String get calendarImportSelectAll =>
      l10n(lang, _m(en: 'Select all', tr: 'Tümünü seç', es: 'Seleccionar todo', fr: 'Tout sélectionner', de: 'Alle auswählen'));
  String get calendarImportDeselectAll => l10n(lang, _m(
        en: 'Deselect all',
        tr: 'Seçimi kaldır',
        es: 'Deseleccionar todo',
        fr: 'Tout désélectionner',
        de: 'Auswahl aufheben',
      ));
  String get calendarImportAllDay =>
      l10n(lang, _m(en: 'All day', tr: 'Tüm gün', es: 'Todo el día', fr: 'Journée entière', de: 'Ganztägig'));
  String get achievementsTitle =>
      l10n(lang, _m(en: 'Achievements', tr: 'Başarımlar', es: 'Logros', fr: 'Succès', de: 'Erfolge'));
  String get achievementsNav =>
      l10n(lang, _m(en: 'Badges', tr: 'Rozetler', es: 'Logros', fr: 'Badges', de: 'Abzeichen'));
  String get achievementsSubtitle => l10n(lang, _m(
        en: 'Complete tasks to unlock badges.',
        tr: 'Görevleri tamamlayarak rozetleri aç.',
        es: 'Completa tareas para desbloquear insignias.',
        fr: 'Terminez des tâches pour débloquer des badges.',
        de: 'Schließe Aufgaben ab, um Abzeichen freizuschalten.',
      ));
  String achievementsUnlocked(int unlocked, int total) => l10n(lang, _m(
        en: '$unlocked / $total unlocked',
        tr: '$unlocked / $total açıldı',
        es: '$unlocked / $total desbloqueados',
        fr: '$unlocked / $total débloqués',
        de: '$unlocked / $total freigeschaltet',
      ));
  String get achievementsWeekly =>
      l10n(lang, _m(en: 'This week', tr: 'Bu hafta', es: 'Esta semana', fr: 'Cette semaine', de: 'Diese Woche'));
  String get achievementsAllTime =>
      l10n(lang, _m(en: 'All time', tr: 'Tüm zamanlar', es: 'Todo el tiempo', fr: 'Tous les temps', de: 'Gesamt'));
  String get achievementsStatWeekly =>
      l10n(lang, _m(en: 'This week', tr: 'Bu hafta', es: 'Esta semana', fr: 'Cette semaine', de: 'Diese Woche'));
  String get achievementsStatAllTime =>
      l10n(lang, _m(en: 'All time', tr: 'Tüm zamanlar', es: 'Todo el tiempo', fr: 'Tous les temps', de: 'Gesamt'));
  String get achievementsProfileSubtitle => l10n(lang, _m(
        en: 'View your badges and progress',
        tr: 'Rozetlerini ve ilerlemeni gör',
        es: 'Ver tus insignias y progreso',
        fr: 'Voir vos badges et votre progression',
        de: 'Abzeichen und Fortschritt ansehen',
      ));

  String achievementTitle(AchievementDefinition def) {
    if (def.scope == AchievementScope.weekly) {
      switch (def.target) {
        case 1:
          return l10n(lang, _m(en: 'Week Starter', tr: 'Haftaya Başlangıç', es: 'Inicio de semana', fr: 'Début de semaine', de: 'Wochenstart'));
        case 5:
          return l10n(lang, _m(en: 'Weekly Momentum', tr: 'Haftalık Ivme', es: 'Impulso semanal', fr: 'Élan hebdomadaire', de: 'Wochen-Schwung'));
        case 10:
          return l10n(lang, _m(en: 'Weekly Flow', tr: 'Haftalık Akış', es: 'Flujo semanal', fr: 'Flow hebdomadaire', de: 'Wochen-Flow'));
        case 20:
          return l10n(lang, _m(en: 'Week Champion', tr: 'Haftanın Şampiyonu', es: 'Campeón de la semana', fr: 'Champion de la semaine', de: 'Wochen-Champion'));
        default:
          return achievementCountTitle(def.target);
      }
    }

    switch (def.target) {
      case 1:
        return l10n(lang, _m(en: 'First Step', tr: 'İlk Adım', es: 'Primer paso', fr: 'Premier pas', de: 'Erster Schritt'));
      case 5:
        return l10n(lang, _m(en: 'On a Roll', tr: 'Ivme Kazandın', es: 'En racha', fr: 'En forme', de: 'Im Flow'));
      case 25:
        return l10n(lang, _m(en: 'Productive', tr: 'Üretken', es: 'Productivo', fr: 'Productif', de: 'Produktiv'));
      case 100:
        return l10n(lang, _m(en: 'Task Master', tr: 'Görev Ustası', es: 'Maestro de tareas', fr: 'Maître des tâches', de: 'Aufgabenmeister'));
      default:
        return achievementCountTitle(def.target);
    }
  }

  String achievementDescription(AchievementDefinition def) {
    if (def.scope == AchievementScope.weekly) {
      return achievementWeeklyDescription(def.target);
    }
    return achievementAllTimeDescription(def.target);
  }

  String achievementCountTitle(int count) => l10n(lang, _m(
        en: '$count Tasks',
        tr: '$count Görev',
        es: '$count tareas',
        fr: '$count tâches',
        de: '$count Aufgaben',
      ));

  String achievementWeeklyDescription(int count) => l10n(lang, _m(
        en: 'Complete $count tasks this week.',
        tr: 'Bu hafta $count görev tamamla.',
        es: 'Completa $count tareas esta semana.',
        fr: 'Terminez $count tâches cette semaine.',
        de: 'Schließe diese Woche $count Aufgaben ab.',
      ));

  String achievementAllTimeDescription(int count) => l10n(lang, _m(
        en: 'Complete $count tasks in total.',
        tr: 'Toplam $count görev tamamla.',
        es: 'Completa $count tareas en total.',
        fr: 'Terminez $count tâches au total.',
        de: 'Schließe insgesamt $count Aufgaben ab.',
      ));

  // Tasks
  String get taskOptions =>
      l10n(lang, _m(en: 'Task options', tr: 'Görev seçenekleri', es: 'Opciones de tarea', fr: 'Options de tâche', de: 'Aufgabenoptionen'));
  String get startTask =>
      l10n(lang, _m(en: 'Start task', tr: 'Göreve başla', es: 'Iniciar tarea', fr: 'Commencer la tâche', de: 'Aufgabe starten'));
  String get start =>
      l10n(lang, _m(en: 'Start', tr: 'Başlat', es: 'Iniciar', fr: 'Démarrer', de: 'Starten'));
  String get edit => l10n(lang, _m(en: 'Edit', tr: 'Düzenle', es: 'Editar', fr: 'Modifier', de: 'Bearbeiten'));
  String get delete => l10n(lang, _m(en: 'Delete', tr: 'Sil', es: 'Eliminar', fr: 'Supprimer', de: 'Löschen'));
  String get splitSubtasks =>
      l10n(lang, _m(en: 'Split into subtasks', tr: 'Adımlara böl', es: 'Dividir en pasos', fr: 'Diviser en étapes', de: 'In Schritte aufteilen'));
  String get goToFocus =>
      l10n(lang, _m(en: 'Go to focus', tr: 'Odağa git', es: 'Ir al enfoque', fr: 'Aller au focus', de: 'Zum Fokus'));
  String get pause => l10n(lang, _m(en: 'Pause', tr: 'Duraklat', es: 'Pausar', fr: 'Pause', de: 'Pause'));
  String get resume => l10n(lang, _m(en: 'Resume', tr: 'Devam et', es: 'Reanudar', fr: 'Reprendre', de: 'Fortsetzen'));
  String get complete => l10n(lang, _m(en: 'Complete', tr: 'Tamamla', es: 'Completar', fr: 'Terminer', de: 'Abschließen'));
  String get undoComplete =>
      l10n(lang, _m(en: 'Undo complete', tr: 'Tamamlamayı geri al', es: 'Deshacer completado', fr: 'Annuler la complétion', de: 'Abschluss rückgängig'));
  String get taskCompletedUndo =>
      l10n(lang, _m(en: 'Task completed', tr: 'Görev tamamlandı', es: 'Tarea completada', fr: 'Tâche terminée', de: 'Aufgabe abgeschlossen'));
  String get undo =>
      l10n(lang, _m(en: 'Undo', tr: 'Geri al', es: 'Deshacer', fr: 'Annuler', de: 'Rückgängig'));
  String get deleteTask =>
      l10n(lang, _m(en: 'Delete task', tr: 'Görevi sil', es: 'Eliminar tarea', fr: 'Supprimer la tâche', de: 'Aufgabe löschen'));
  String get deleteConfirm =>
      l10n(lang, _m(en: 'Delete this task?', tr: 'Bu görev silinsin mi?', es: '¿Eliminar esta tarea?', fr: 'Supprimer cette tâche ?', de: 'Diese Aufgabe löschen?'));
  String get deleteRecurringTask =>
      l10n(lang, _m(en: 'Delete recurring task', tr: 'Tekrarlayan görevi sil', es: 'Eliminar tarea recurrente', fr: 'Supprimer la tâche récurrente', de: 'Wiederkehrende Aufgabe löschen'));
  String deleteRecurringTaskPrompt(String title) => l10n(lang, _m(
        en: '“$title” is part of a recurring series. What should be deleted?',
        tr: '“$title” tekrarlayan bir serinin parçası. Ne silinsin?',
        es: '“$title” forma parte de una serie recurrente. ¿Qué deseas eliminar?',
        fr: '« $title » fait partie d\'une série récurrente. Que supprimer ?',
        de: '„$title“ ist Teil einer wiederkehrenden Serie. Was soll gelöscht werden?',
      ));
  String get deleteRecurringThis =>
      l10n(lang, _m(en: 'Only this occurrence', tr: 'Sadece bunu', es: 'Solo esta ocurrencia', fr: 'Seulement celle-ci', de: 'Nur dieses Vorkommen'));
  String get deleteRecurringFuture =>
      l10n(lang, _m(en: 'This and future occurrences', tr: 'Bunu ve sonrakileri', es: 'Esta y las futuras', fr: 'Celle-ci et les suivantes', de: 'Dieses und zukünftige'));
  String get deleteRecurringAll =>
      l10n(lang, _m(en: 'All occurrences', tr: 'Hepsini', es: 'Todas las ocurrencias', fr: 'Toutes les occurrences', de: 'Alle Vorkommen'));
  String get addTask =>
      l10n(lang, _m(en: 'Add task', tr: 'Görev Ekle', es: 'Añadir tarea', fr: 'Ajouter une tâche', de: 'Aufgabe hinzufügen'));
  String get newTask =>
      l10n(lang, _m(en: 'New task', tr: 'Yeni Görev', es: 'Nueva tarea', fr: 'Nouvelle tâche', de: 'Neue Aufgabe'));
  String get taskDetails =>
      l10n(lang, _m(en: 'Details', tr: 'Ayrıntılar', es: 'Detalles', fr: 'Détails', de: 'Details'));
  String get recurringTask =>
      l10n(lang, _m(en: 'Recurring', tr: 'Tekrarlayan', es: 'Recurrente', fr: 'Récurrent', de: 'Wiederkehrend'));
  String get editTask =>
      l10n(lang, _m(en: 'Edit task', tr: 'Görevi Düzenle', es: 'Editar tarea', fr: 'Modifier la tâche', de: 'Aufgabe bearbeiten'));
  String get editStep =>
      l10n(lang, _m(en: 'Edit step', tr: 'Adımı Düzenle', es: 'Editar paso', fr: 'Modifier l\'étape', de: 'Schritt bearbeiten'));
  String get taskNameHint =>
      l10n(lang, _m(en: 'Task name...', tr: 'Görev adı...', es: 'Nombre de la tarea...', fr: 'Nom de la tâche...', de: 'Aufgabenname...'));
  String get rewardLabel =>
      l10n(lang, _m(en: 'Reward', tr: 'Ödül', es: 'Recompensa', fr: 'Récompense', de: 'Belohnung'));
  String get rewardHint => l10n(lang, _m(
        en: 'What will you treat yourself to?',
        tr: 'Kendine ne ödül vereceksin?',
        es: '¿Con qué te recompensarás?',
        fr: 'Comment allez-vous vous récompenser ?',
        de: 'Womit belohnst du dich?',
      ));
  String get rewardOptionalHint => l10n(lang, _m(
        en: 'Optional — a little motivation when you finish',
        tr: 'İsteğe bağlı — bitirince seni motive etsin',
        es: 'Opcional — un extra de motivación al terminar',
        fr: 'Facultatif — une motivation à la fin',
        de: 'Optional — Motivation nach dem Abschluss',
      ));
  String get taskCompletedTitle =>
      l10n(lang, _m(en: 'Well done!', tr: 'Tebrikler!', es: '¡Bien hecho!', fr: 'Bravo !', de: 'Gut gemacht!'));
  String taskCompletedSubtitle(String title) => l10n(lang, _m(
        en: 'You completed "$title"',
        tr: '"$title" görevini tamamladın',
        es: 'Completaste "$title"',
        fr: 'Vous avez terminé « $title »',
        de: 'Du hast „$title“ abgeschlossen',
      ));
  String get yourReward =>
      l10n(lang, _m(en: 'Your reward', tr: 'Ödülün', es: 'Tu recompensa', fr: 'Votre récompense', de: 'Deine Belohnung'));
  String get rewardReminder => l10n(lang, _m(
        en: 'Time to enjoy your reward!',
        tr: 'Şimdi ödülünün tadını çıkarma zamanı!',
        es: '¡Es hora de disfrutar tu recompensa!',
        fr: 'Il est temps de profiter de votre récompense !',
        de: 'Zeit, deine Belohnung zu genießen!',
      ));
  String get awesome =>
      l10n(lang, _m(en: 'Awesome!', tr: 'Harika!', es: '¡Genial!', fr: 'Super !', de: 'Super!'));
  String get addTaskButton =>
      l10n(lang, _m(en: 'Add task', tr: 'Görevi Ekle', es: 'Añadir tarea', fr: 'Ajouter la tâche', de: 'Aufgabe hinzufügen'));
  String get addTaskAndSteps =>
      l10n(lang, _m(en: 'Add task and steps', tr: 'Görev ve Adımları Ekle', es: 'Añadir tarea y pasos', fr: 'Ajouter tâche et étapes', de: 'Aufgabe und Schritte hinzufügen'));
  String get addFirstTask =>
      l10n(lang, _m(en: 'Add first task', tr: 'İlk Görevi Ekle', es: 'Añadir primera tarea', fr: 'Ajouter la première tâche', de: 'Erste Aufgabe hinzufügen'));
  String get duration =>
      l10n(lang, _m(en: 'Duration', tr: 'Süre', es: 'Duración', fr: 'Durée', de: 'Dauer'));
  String get aiDuration =>
      l10n(lang, _m(en: 'AI decide', tr: 'AI belirlesin', es: 'Decidir con IA', fr: 'IA décide', de: 'KI entscheidet'));
  String get stepDurations =>
      l10n(lang, _m(en: 'Step durations', tr: 'Adım süreleri', es: 'Duración de pasos', fr: 'Durées des étapes', de: 'Schrittdauern'));
  String get taskReminders =>
      l10n(lang, _m(en: 'Reminders', tr: 'Hatırlatmalar', es: 'Recordatorios', fr: 'Rappels', de: 'Erinnerungen'));
  String get remind10Min =>
      l10n(lang, _m(en: '10 minutes before', tr: '10 dk önce', es: '10 min antes', fr: '10 min avant', de: '10 Min. vorher'));
  String get remind1Min =>
      l10n(lang, _m(en: '1 minute before', tr: '1 dk önce', es: '1 min antes', fr: '1 min avant', de: '1 Min. vorher'));
  String get remind5Min =>
      l10n(lang, _m(en: '5 minutes before', tr: '5 dk önce', es: '5 min antes', fr: '5 min avant', de: '5 Min. vorher'));
  String get remindTransitionEnd => l10n(lang, _m(
        en: 'When task ends',
        tr: 'Görev bitince',
        es: 'Al terminar la tarea',
        fr: 'À la fin de la tâche',
        de: 'Wenn die Aufgabe endet',
      ));
  String taskReminder5(String title) => l10n(lang, _m(
        en: '$title starts in 5 minutes — get ready',
        tr: '$title 5 dakika içinde başlıyor — hazırlan',
        es: '$title empieza en 5 minutos — prepárate',
        fr: '« $title » commence dans 5 minutes — préparez-vous',
        de: '„$title“ beginnt in 5 Minuten — mach dich bereit',
      ));
  String taskReminderTransition(String title, String next) => l10n(lang, _m(
        en: '$title is ending — switch to $next',
        tr: '$title bitiyor — $next görevine geç',
        es: '$title termina — pasa a $next',
        fr: '« $title » se termine — passez à « $next »',
        de: '„$title“ endet — wechsle zu „$next“',
      ));
  String taskReminderEnd(String title) => l10n(lang, _m(
        en: '$title is done — time to transition',
        tr: '$title bitti — geçiş zamanı',
        es: '$title terminó — hora de cambiar',
        fr: '« $title » est terminé — temps de transition',
        de: '„$title“ ist fertig — Zeit zum Wechseln',
      ));
  String get taskReminderTitle =>
      l10n(lang, _m(en: 'Upcoming task', tr: 'Yaklaşan görev', es: 'Tarea próxima', fr: 'Tâche à venir', de: 'Anstehende Aufgabe'));
  String taskReminder10(String title) => l10n(lang, _m(
        en: '$title starts in 10 minutes',
        tr: '$title 10 dakika içinde başlıyor',
        es: '$title empieza en 10 minutos',
        fr: '« $title » commence dans 10 minutes',
        de: '„$title“ beginnt in 10 Minuten',
      ));
  String taskReminder1(String title) => l10n(lang, _m(
        en: '$title starts in 1 minute',
        tr: '$title 1 dakika içinde başlıyor',
        es: '$title empieza en 1 minuto',
        fr: '« $title » commence dans 1 minute',
        de: '„$title“ beginnt in 1 Minute',
      ));
  String get timerSeekBack5 =>
      l10n(lang, _m(en: '-5m', tr: '-5dk', es: '-5m', fr: '-5m', de: '-5m'));
  String get timerSeekBack1 =>
      l10n(lang, _m(en: '-1m', tr: '-1dk', es: '-1m', fr: '-1m', de: '-1m'));
  String get timerSeekForward1 =>
      l10n(lang, _m(en: '+1m', tr: '+1dk', es: '+1m', fr: '+1m', de: '+1m'));
  String get timerSeekForward5 =>
      l10n(lang, _m(en: '+5m', tr: '+5dk', es: '+5m', fr: '+5m', de: '+5m'));
  String get timerDragHint => l10n(lang, _m(
        en: 'Drag the ring to adjust',
        tr: 'Süreyi daire üzerinde kaydır',
        es: 'Arrastra el anillo para ajustar',
        fr: 'Faites glisser l\'anneau',
        de: 'Ring zum Anpassen ziehen',
      ));
  String get time => l10n(lang, _m(en: 'Time', tr: 'Saat', es: 'Hora', fr: 'Heure', de: 'Uhrzeit'));
  String get color => l10n(lang, _m(en: 'Color', tr: 'Renk', es: 'Color', fr: 'Couleur', de: 'Farbe'));
  String get repeat => l10n(lang, _m(en: 'Repeat', tr: 'Tekrar', es: 'Repetir', fr: 'Répéter', de: 'Wiederholen'));
  String get repeatNone =>
      l10n(lang, _m(en: 'No repeat', tr: 'Tekrar yok', es: 'Sin repetición', fr: 'Pas de répétition', de: 'Keine Wiederholung'));
  String get repeatDaily =>
      l10n(lang, _m(en: 'Daily', tr: 'Günlük', es: 'Diario', fr: 'Quotidien', de: 'Täglich'));
  String get repeatWeekly =>
      l10n(lang, _m(en: 'Weekly', tr: 'Haftalık', es: 'Semanal', fr: 'Hebdomadaire', de: 'Wöchentlich'));
  String get repeatMonthly =>
      l10n(lang, _m(en: 'Monthly', tr: 'Aylık', es: 'Mensual', fr: 'Mensuel', de: 'Monatlich'));
  String get repeatYearly =>
      l10n(lang, _m(en: 'Yearly', tr: 'Yıllık', es: 'Anual', fr: 'Annuel', de: 'Jährlich'));
  String get repeatCustom =>
      l10n(lang, _m(en: 'Custom', tr: 'Özel', es: 'Personalizado', fr: 'Personnalisé', de: 'Benutzerdefiniert'));
  String get repeatEvery =>
      l10n(lang, _m(en: 'Every', tr: 'Her', es: 'Cada', fr: 'Tous les', de: 'Alle'));
  String repeatDays(int count) => l10n(lang, _m(
        en: count == 1 ? 'day' : 'days',
        tr: 'gün',
        es: count == 1 ? 'día' : 'días',
        fr: count == 1 ? 'jour' : 'jours',
        de: count == 1 ? 'Tag' : 'Tage',
      ));
  String repeatWeeks(int count) => l10n(lang, _m(
        en: count == 1 ? 'week' : 'weeks',
        tr: 'hafta',
        es: count == 1 ? 'semana' : 'semanas',
        fr: count == 1 ? 'semaine' : 'semaines',
        de: count == 1 ? 'Woche' : 'Wochen',
      ));
  String repeatMonths(int count) => l10n(lang, _m(
        en: count == 1 ? 'month' : 'months',
        tr: 'ay',
        es: count == 1 ? 'mes' : 'meses',
        fr: count == 1 ? 'mois' : 'mois',
        de: count == 1 ? 'Monat' : 'Monate',
      ));

  String recurrenceTypeLabel(RecurrenceType type) => switch (type) {
        RecurrenceType.none => repeatNone,
        RecurrenceType.daily => repeatDaily,
        RecurrenceType.weekly => repeatWeekly,
        RecurrenceType.monthly => repeatMonthly,
        RecurrenceType.yearly => repeatYearly,
        RecurrenceType.custom => repeatCustom,
      };

  String recurrenceUnitLabel(RecurrenceUnit unit) => switch (unit) {
        RecurrenceUnit.days => repeatDays(2),
        RecurrenceUnit.weeks => repeatWeeks(2),
        RecurrenceUnit.months => repeatMonths(2),
      };

  String recurrenceLabel(RecurrenceSelection selection) {
    if (selection.type == RecurrenceType.none) return repeatNone;
    if (selection.type == RecurrenceType.custom) {
      final unit = switch (selection.unit) {
        RecurrenceUnit.days => repeatDays(selection.interval),
        RecurrenceUnit.weeks => repeatWeeks(selection.interval),
        RecurrenceUnit.months => repeatMonths(selection.interval),
      };
      return l10n(lang, _m(
        en: 'Every ${selection.interval} $unit',
        tr: 'Her ${selection.interval} $unit',
        es: 'Cada ${selection.interval} $unit',
        fr: 'Tous les ${selection.interval} $unit',
        de: 'Alle ${selection.interval} $unit',
      ));
    }
    return recurrenceTypeLabel(selection.type);
  }

  String get splitIntoSteps =>
      l10n(lang, _m(en: 'Split into steps', tr: 'Adımlara böl', es: 'Dividir en pasos', fr: 'Diviser en étapes', de: 'In Schritte aufteilen'));
  String get splitIntoStepsHint => l10n(lang, _m(
        en: 'AI breaks the task into smaller steps',
        tr: 'AI görevi küçük adımlara ayırır',
        es: 'La IA divide la tarea en pasos más pequeños',
        fr: 'L\'IA divise la tâche en petites étapes',
        de: 'KI teilt die Aufgabe in kleinere Schritte',
      ));

  // AI
  String get aiBreakdown =>
      l10n(lang, _m(en: 'AI subtask breakdown', tr: 'AI ile adımlara böl', es: 'División con IA', fr: 'Découpage IA', de: 'KI-Aufteilung'));
  String get aiBreakdownHint => l10n(lang, _m(
        en: 'Split this task into smaller steps with AI.',
        tr: 'Bu görevi AI ile küçük adımlara ayır.',
        es: 'Divide esta tarea en pasos más pequeños con IA.',
        fr: 'Divisez cette tâche en petites étapes avec l\'IA.',
        de: 'Teile diese Aufgabe mit KI in kleinere Schritte.',
      ));
  String get previewSteps =>
      l10n(lang, _m(en: 'Preview steps', tr: 'Adımları önizle', es: 'Vista previa de pasos', fr: 'Aperçu des étapes', de: 'Schritte anzeigen'));
  String get applySteps =>
      l10n(lang, _m(en: 'Apply steps', tr: 'Adımları uygula', es: 'Aplicar pasos', fr: 'Appliquer les étapes', de: 'Schritte anwenden'));
  String get aiThinking =>
      l10n(lang, _m(en: 'AI is thinking...', tr: 'AI düşünüyor...', es: 'La IA está pensando...', fr: 'L\'IA réfléchit...', de: 'KI denkt nach...'));
  String get applyingSteps =>
      l10n(lang, _m(en: 'Applying steps...', tr: 'Adımlar ekleniyor...', es: 'Aplicando pasos...', fr: 'Application des étapes...', de: 'Schritte werden hinzugefügt...'));
  String get aiPlanner =>
      l10n(lang, _m(en: 'AI Planner', tr: 'AI Planlayıcı', es: 'Planificador IA', fr: 'Planificateur IA', de: 'KI-Planer'));
  String get planDay =>
      l10n(lang, _m(en: 'Plan day', tr: 'Gün Planla', es: 'Planificar día', fr: 'Planifier la journée', de: 'Tag planen'));
  String get splitTask =>
      l10n(lang, _m(en: 'Split task', tr: 'Görev Böl', es: 'Dividir tarea', fr: 'Diviser la tâche', de: 'Aufgabe teilen'));
  String get createPlan =>
      l10n(lang, _m(en: 'Create plan', tr: 'Plan Oluştur', es: 'Crear plan', fr: 'Créer un plan', de: 'Plan erstellen'));
  String get addPlanToDay =>
      l10n(lang, _m(en: 'Add plan to day', tr: 'Planı Güne Ekle', es: 'Añadir plan al día', fr: 'Ajouter le plan au jour', de: 'Plan zum Tag hinzufügen'));
  String get poweredByGroq => 'Powered by Groq AI';

  String get planPrompt => l10n(lang, _m(
        en: 'Brain dump your day — write or speak freely',
        tr: 'Günü beyin dökümü yap — serbestçe yaz veya söyle',
        es: 'Vuelca tu día — escribe o habla libremente',
        fr: 'Déchargez votre journée — écrivez ou parlez librement',
        de: 'Gedanken abladen — schreibe oder sprich frei',
      ));
  String get breakdownPrompt => l10n(lang, _m(
        en: 'Write or speak the big task',
        tr: 'Büyük görevi yaz veya sesle söyle',
        es: 'Escribe o habla la tarea grande',
        fr: 'Écrivez ou dites la grande tâche',
        de: 'Schreibe oder sprich die große Aufgabe',
      ));
  String get planExample => l10n(lang, _m(
        en: 'E.g. "Morning workout, afternoon meeting, evening shopping"',
        tr: 'Örn: "Sabah spor, öğleden sonra toplantı, akşam alışveriş"',
        es: 'Ej.: "Ejercicio por la mañana, reunión por la tarde, compras por la noche"',
        fr: 'Ex. : « Sport le matin, réunion l\'après-midi, courses le soir »',
        de: 'Z.B. „Morgens Sport, nachmittags Meeting, abends einkaufen"',
      ));
  String get breakdownExample => l10n(lang, _m(
        en: 'E.g. "Clean the house" → breaks into small steps',
        tr: 'Örn: "Ev temizliği yapacağım" → küçük adımlara böler',
        es: 'Ej.: "Limpiar la casa" → lo divide en pasos pequeños',
        fr: 'Ex. : « Nettoyer la maison » → divise en petites étapes',
        de: 'Z.B. „Haus putzen" → teilt in kleine Schritte',
      ));
  String get planHint => l10n(lang, _m(
        en: 'Pour everything out — AI will organize a schedule',
        tr: 'Kafandaki her şeyi yaz — AI bir program oluştursun',
        es: 'Suelta todo — la IA organizará un horario',
        fr: 'Déversez tout — l\'IA organisera un planning',
        de: 'Schreib alles auf — die KI erstellt einen Plan',
      ));
  String get breakdownHint => l10n(lang, _m(
        en: 'Which task should we split?',
        tr: 'Hangi görevi bölelim?',
        es: '¿Qué tarea dividimos?',
        fr: 'Quelle tâche diviser ?',
        de: 'Welche Aufgabe sollen wir teilen?',
      ));

  // Home & navigation
  String hello(String name) =>
      l10n(lang, _m(en: 'Hello, $name 👋', tr: 'Merhaba, $name 👋', es: 'Hola, $name 👋', fr: 'Bonjour, $name 👋', de: 'Hallo, $name 👋'));
  String get hourView =>
      l10n(lang, _m(en: 'Hour view', tr: 'Saat görünümü', es: 'Vista por horas', fr: 'Vue horaire', de: 'Stundenansicht'));
  String get listView =>
      l10n(lang, _m(en: 'List view', tr: 'Liste görünümü', es: 'Vista de lista', fr: 'Vue liste', de: 'Listenansicht'));
  String get today => l10n(lang, _m(en: 'Today', tr: 'Bugün', es: 'Hoy', fr: 'Aujourd\'hui', de: 'Heute'));
  String get todoNav => l10n(lang, _m(en: 'To-do', tr: 'Yapılacaklar', es: 'Pendientes', fr: 'À faire', de: 'Aufgaben'));
  String get week => l10n(lang, _m(en: 'Week', tr: 'Hafta', es: 'Semana', fr: 'Semaine', de: 'Woche'));
  String get day => l10n(lang, _m(en: 'Day', tr: 'Gün', es: 'Día', fr: 'Jour', de: 'Tag'));
  String get focus => l10n(lang, _m(en: 'Focus', tr: 'Odak', es: 'Enfoque', fr: 'Focus', de: 'Fokus'));
  String get more => l10n(lang, _m(en: 'More', tr: 'Daha fazla', es: 'Más', fr: 'Plus', de: 'Mehr'));
  String get moreSubtitle => l10n(lang, _m(
        en: 'Week, badges & settings',
        tr: 'Hafta, rozetler ve ayarlar',
        es: 'Semana, logros y ajustes',
        fr: 'Semaine, badges et réglages',
        de: 'Woche, Abzeichen & Einstellungen',
      ));
  String get weeklyPlanSummary => l10n(lang, _m(
        en: 'Weekly plan summary',
        tr: 'Haftalık plan özeti',
        es: 'Resumen semanal',
        fr: 'Résumé hebdomadaire',
        de: 'Wochenübersicht',
      ));
  String get focusTimer =>
      l10n(lang, _m(en: 'Focus timer', tr: 'Odak zamanlayıcı', es: 'Temporizador de enfoque', fr: 'Minuteur de focus', de: 'Fokus-Timer'));
  String get todaysPlan =>
      l10n(lang, _m(en: 'Today\'s plan', tr: 'Günün Planı', es: 'Plan de hoy', fr: 'Plan du jour', de: 'Tagesplan'));
  String get connectionError =>
      l10n(lang, _m(en: 'Connection error', tr: 'Bağlantı hatası', es: 'Error de conexión', fr: 'Erreur de connexion', de: 'Verbindungsfehler'));
  String get retry => l10n(lang, _m(en: 'Try again', tr: 'Tekrar Dene', es: 'Reintentar', fr: 'Réessayer', de: 'Erneut versuchen'));
  String get noPlanToday =>
      l10n(lang, _m(en: 'No plan for today', tr: 'Bugün için plan yok', es: 'Sin plan para hoy', fr: 'Aucun plan pour aujourd\'hui', de: 'Kein Plan für heute'));
  String get emptyPlanHint => l10n(lang, _m(
        en: 'Start your day by adding your first task.\nSmall steps make a big difference.',
        tr: 'İlk görevini ekleyerek güne başla.\nKüçük adımlar büyük fark yaratır.',
        es: 'Empieza el día añadiendo tu primera tarea.\nLos pequeños pasos marcan la diferencia.',
        fr: 'Commencez la journée en ajoutant votre première tâche.\nLes petits pas font la différence.',
        de: 'Starte den Tag mit deiner ersten Aufgabe.\nKleine Schritte bewirken Großes.',
      ));

  // Progress & status
  String get dayEmpty => l10n(lang, _m(en: 'Day is empty', tr: 'Gün boş', es: 'Día vacío', fr: 'Journée vide', de: 'Tag ist leer'));
  String get active => l10n(lang, _m(en: 'Active', tr: 'Aktif', es: 'Activo', fr: 'Actif', de: 'Aktiv'));
  String get paused =>
      l10n(lang, _m(en: 'Paused', tr: 'Duraklatıldı', es: 'En pausa', fr: 'En pause', de: 'Pausiert'));
  String get pausedUpper =>
      l10n(lang, _m(en: 'PAUSED', tr: 'DURAKLATILDI', es: 'EN PAUSA', fr: 'EN PAUSE', de: 'PAUSIERT'));
  String get currentlyActive =>
      l10n(lang, _m(en: 'Currently active', tr: 'Şu an aktif', es: 'Activo ahora', fr: 'Actif maintenant', de: 'Gerade aktiv'));
  String get oneTaskActive =>
      l10n(lang, _m(en: 'One task is active', tr: 'Bir görev şu an aktif', es: 'Una tarea está activa', fr: 'Une tâche est active', de: 'Eine Aufgabe ist aktiv'));
  String get addFirstTaskHint => l10n(lang, _m(
        en: 'Add your first task to get started',
        tr: 'İlk görevini ekleyerek başla',
        es: 'Añade tu primera tarea para empezar',
        fr: 'Ajoutez votre première tâche pour commencer',
        de: 'Füge deine erste Aufgabe hinzu',
      ));
  String get remainingTime =>
      l10n(lang, _m(en: 'remaining', tr: 'kalan süre', es: 'restante', fr: 'restant', de: 'verbleibend'));
  String get finish => l10n(lang, _m(en: 'Finish', tr: 'Bitir', es: 'Terminar', fr: 'Terminer', de: 'Beenden'));
  String get continueLabel =>
      l10n(lang, _m(en: 'Continue', tr: 'Devam', es: 'Continuar', fr: 'Continuer', de: 'Weiter'));
  String get focusModeOff =>
      l10n(lang, _m(en: 'Focus mode is off', tr: 'Odak modu kapalı', es: 'Modo enfoque desactivado', fr: 'Mode focus désactivé', de: 'Fokusmodus aus'));
  String get focusModeHint => l10n(lang, _m(
        en: 'Start a task or begin a free focus session for anything you want.\nTrack it here or from the lock screen widget.',
        tr: 'Bir görev başlat veya istediğin herhangi bir şey için serbest odak seansı aç.\nBuradan veya kilit ekranı widget\'ından takip edebilirsin.',
        es: 'Inicia una tarea o comienza una sesión libre para lo que quieras.\nSíguela aquí o desde el widget de la pantalla de bloqueo.',
        fr: 'Démarrez une tâche ou une session libre pour ce que vous voulez.\nSuivez-la ici ou depuis le widget de l\'écran verrouillé.',
        de: 'Starte eine Aufgabe oder eine freie Fokussitzung für alles, was du willst.\nVerfolge sie hier oder über das Sperrbildschirm-Widget.',
      ));
  String get startFocus =>
      l10n(lang, _m(en: 'Start focus', tr: 'Odak başlat', es: 'Iniciar enfoque', fr: 'Démarrer le focus', de: 'Fokus starten'));
  String get focusWhatHint => l10n(lang, _m(
        en: 'What are you focusing on?',
        tr: 'Ne üzerinde odaklanacaksın?',
        es: '¿En qué te concentras?',
        fr: 'Sur quoi vous concentrez-vous ?',
        de: 'Worauf konzentrierst du dich?',
      ));
  String get freeFocusTitle =>
      l10n(lang, _m(en: 'Focus session', tr: 'Odak seansı', es: 'Sesión de enfoque', fr: 'Session focus', de: 'Fokussitzung'));
  String get focusModeOn => l10n(lang, _m(
        en: 'You\'re in focus mode — keep going!',
        tr: 'Odak modundasın — devam et!',
        es: 'Estás en modo enfoque — ¡sigue!',
        fr: 'Vous êtes en mode focus — continuez !',
        de: 'Du bist im Fokusmodus — weiter so!',
      ));
  String get quickStart =>
      l10n(lang, _m(en: 'Quick start', tr: 'Hızlı başlat', es: 'Inicio rápido', fr: 'Démarrage rapide', de: 'Schnellstart'));
  String get focusMode =>
      l10n(lang, _m(en: 'Focus mode', tr: 'Odak Modu', es: 'Modo enfoque', fr: 'Mode focus', de: 'Fokusmodus'));
  String get noActiveTask =>
      l10n(lang, _m(en: 'No active task', tr: 'Aktif görev yok', es: 'Sin tarea activa', fr: 'Aucune tâche active', de: 'Keine aktive Aufgabe'));
  String get nextUp => l10n(lang, _m(en: 'Up next', tr: 'Sıradaki', es: 'Siguiente', fr: 'À suivre', de: 'Als Nächstes'));
  String get noPlanWidget =>
      l10n(lang, _m(en: 'No plan today', tr: 'Bugün plan yok', es: 'Sin plan hoy', fr: 'Aucun plan aujourd\'hui', de: 'Kein Plan heute'));

  // Auth
  String get loginTagline => l10n(lang, _m(
        en: 'Your visual daily planner',
        tr: 'Görsel günlük planlayıcın',
        es: 'Tu planificador visual diario',
        fr: 'Votre planificateur visuel quotidien',
        de: 'Dein visueller Tagesplaner',
      ));
  String get email => l10n(lang, _m(en: 'Email', tr: 'E-posta', es: 'Correo', fr: 'E-mail', de: 'E-Mail'));
  String get password => l10n(lang, _m(en: 'Password', tr: 'Şifre', es: 'Contraseña', fr: 'Mot de passe', de: 'Passwort'));
  String get emailRequired =>
      l10n(lang, _m(en: 'Email required', tr: 'E-posta gerekli', es: 'Correo obligatorio', fr: 'E-mail requis', de: 'E-Mail erforderlich'));
  String get passwordMin6 =>
      l10n(lang, _m(en: 'At least 6 characters', tr: 'En az 6 karakter', es: 'Al menos 6 caracteres', fr: 'Au moins 6 caractères', de: 'Mindestens 6 Zeichen'));
  String get login => l10n(lang, _m(en: 'Log in', tr: 'Giriş Yap', es: 'Iniciar sesión', fr: 'Se connecter', de: 'Anmelden'));
  String get loginWithGoogle => l10n(lang, _m(
        en: 'Continue with Google',
        tr: 'Google ile devam et',
        es: 'Continuar con Google',
        fr: 'Continuer avec Google',
        de: 'Mit Google fortfahren',
      ));
  String get loginWithApple => l10n(lang, _m(
        en: 'Continue with Apple',
        tr: 'Apple ile devam et',
        es: 'Continuar con Apple',
        fr: 'Continuer avec Apple',
        de: 'Mit Apple fortfahren',
      ));
  String get orContinueWith => l10n(lang, _m(
        en: 'or',
        tr: 'veya',
        es: 'o',
        fr: 'ou',
        de: 'oder',
      ));
  String get noAccountRegister => l10n(lang, _m(
        en: 'Don\'t have an account? Sign up',
        tr: 'Hesabın yok mu? Kayıt ol',
        es: '¿No tienes cuenta? Regístrate',
        fr: 'Pas de compte ? Inscrivez-vous',
        de: 'Noch kein Konto? Registrieren',
      ));
  String get createAccount =>
      l10n(lang, _m(en: 'Create account', tr: 'Hesap Oluştur', es: 'Crear cuenta', fr: 'Créer un compte', de: 'Konto erstellen'));
  String get registerSubtitle => l10n(lang, _m(
        en: 'Sign up to start planning',
        tr: 'Planlamaya başlamak için kayıt ol',
        es: 'Regístrate para empezar a planificar',
        fr: 'Inscrivez-vous pour commencer à planifier',
        de: 'Registriere dich, um mit dem Planen zu beginnen',
      ));
  String get yourName => l10n(lang, _m(en: 'Your name', tr: 'Adın', es: 'Tu nombre', fr: 'Votre nom', de: 'Dein Name'));
  String get nameMin2 =>
      l10n(lang, _m(en: 'At least 2 characters', tr: 'En az 2 karakter', es: 'Al menos 2 caracteres', fr: 'Au moins 2 caractères', de: 'Mindestens 2 Zeichen'));
  String get validEmail =>
      l10n(lang, _m(en: 'Enter a valid email', tr: 'Geçerli e-posta gir', es: 'Introduce un correo válido', fr: 'Entrez un e-mail valide', de: 'Gültige E-Mail eingeben'));
  String get register =>
      l10n(lang, _m(en: 'Sign up', tr: 'Kayıt Ol', es: 'Registrarse', fr: 'S\'inscrire', de: 'Registrieren'));

  // Speech
  String get stopListening =>
      l10n(lang, _m(en: 'Stop listening', tr: 'Dinlemeyi durdur', es: 'Dejar de escuchar', fr: 'Arrêter l\'écoute', de: 'Zuhören beenden'));
  String get speakToType =>
      l10n(lang, _m(en: 'Speak to type', tr: 'Sesle yaz', es: 'Hablar para escribir', fr: 'Parler pour écrire', de: 'Sprechen zum Tippen'));

  // Errors
  String get sessionExpired => l10n(lang, _m(
        en: 'Session expired. Please log in again.',
        tr: 'Oturum süresi doldu. Tekrar giriş yapın.',
        es: 'Sesión expirada. Inicia sesión de nuevo.',
        fr: 'Session expirée. Veuillez vous reconnecter.',
        de: 'Sitzung abgelaufen. Bitte erneut anmelden.',
      ));
  String get aiRequestDenied => l10n(lang, _m(
        en: 'AI request denied. Sign in again, then retry.',
        tr: 'AI isteği reddedildi. Tekrar giriş yapıp deneyin.',
        es: 'Solicitud de IA rechazada. Vuelve a iniciar sesión e inténtalo.',
        fr: 'Requête IA refusée. Reconnectez-vous puis réessayez.',
        de: 'KI-Anfrage abgelehnt. Erneut anmelden und erneut versuchen.',
      ));
  String get aiRequestDeniedWithHint => l10n(lang, _m(
        en: 'AI denied. Check you are signed in and Cloud Functions are deployed.',
        tr: 'AI reddedildi. Giriş yaptığınızdan ve Cloud Functions deploy edildiğinden emin olun.',
        es: 'IA rechazada. Comprueba que has iniciado sesión y que las Functions están desplegadas.',
        fr: 'IA refusée. Vérifiez d\'être connecté et que les Cloud Functions sont déployées.',
        de: 'KI abgelehnt. Prüfe Login und ob Cloud Functions deployed sind.',
      ));
  String get aiEndpointError => l10n(lang, _m(
        en: 'AI endpoint unreachable. Are Cloud Functions deployed?',
        tr: 'AI endpoint erişilemedi. Cloud Functions deploy edildi mi?',
        es: 'Endpoint de IA inaccesible. ¿Functions desplegadas?',
        fr: 'Endpoint IA inaccessible. Functions déployées ?',
        de: 'KI-Endpoint nicht erreichbar. Functions deployed?',
      ));
  String get groqUnavailable => l10n(lang, _m(
        en: 'AI service unavailable. Check the Groq API key.',
        tr: 'AI servisi kullanılamıyor. Groq API anahtarını kontrol edin.',
        es: 'Servicio de IA no disponible. Comprueba la clave API de Groq.',
        fr: 'Service IA indisponible. Vérifiez la clé API Groq.',
        de: 'KI-Dienst nicht verfügbar. Groq-API-Schlüssel prüfen.',
      ));
  String get serverUnreachable => l10n(lang, _m(
        en: 'Could not connect to server. Check your internet connection.',
        tr: 'Sunucuya bağlanılamadı. İnternet bağlantını kontrol et.',
        es: 'No se pudo conectar al servidor. Comprueba tu conexión.',
        fr: 'Impossible de se connecter au serveur. Vérifiez votre connexion.',
        de: 'Verbindung zum Server fehlgeschlagen. Internet prüfen.',
      ));
  String errorPrefix(Object error) => l10n(lang, _m(
        en: 'Error: $error',
        tr: 'Hata: $error',
        es: 'Error: $error',
        fr: 'Erreur : $error',
        de: 'Fehler: $error',
      ));
  String weeklyLoadError(Object error) => l10n(lang, _m(
        en: 'Could not load weekly plan: $error',
        tr: 'Haftalık plan yüklenemedi: $error',
        es: 'No se pudo cargar el plan semanal: $error',
        fr: 'Impossible de charger le plan hebdomadaire : $error',
        de: 'Wochenplan konnte nicht geladen werden: $error',
      ));

  String languageName(String code) => switch (code) {
        'en' => 'English',
        'tr' => 'Türkçe',
        'es' => 'Español',
        'fr' => 'Français',
        'de' => 'Deutsch',
        _ => code,
      };

  String minutesShort(int minutes) => l10n(lang, _m(
        en: '$minutes min',
        tr: '$minutes dk',
        es: '$minutes min',
        fr: '$minutes min',
        de: '$minutes Min.',
      ));

  String taskCount(int count) => l10n(lang, _m(
        en: count == 1 ? '1 task' : '$count tasks',
        tr: '$count görev',
        es: count == 1 ? '1 tarea' : '$count tareas',
        fr: count == 1 ? '1 tâche' : '$count tâches',
        de: count == 1 ? '1 Aufgabe' : '$count Aufgaben',
      ));

  String tasksCompleted(int completed, int total) => l10n(lang, _m(
        en: '$completed / $total tasks completed',
        tr: '$completed / $total görev tamamlandı',
        es: '$completed / $total tareas completadas',
        fr: '$completed / $total tâches terminées',
        de: '$completed / $total Aufgaben erledigt',
      ));

  String tasksRemaining(int count) => l10n(lang, _m(
        en: count == 1 ? '1 task remaining' : '$count tasks remaining',
        tr: '$count görev kaldı',
        es: count == 1 ? '1 tarea restante' : '$count tareas restantes',
        fr: count == 1 ? '1 tâche restante' : '$count tâches restantes',
        de: count == 1 ? '1 Aufgabe übrig' : '$count Aufgaben übrig',
      ));

  String stepsProgress(int completed, int total) => l10n(lang, _m(
        en: '$completed/$total steps',
        tr: '$completed/$total adım',
        es: '$completed/$total pasos',
        fr: '$completed/$total étapes',
        de: '$completed/$total Schritte',
      ));

  String stepsCount(int count) => l10n(lang, _m(
        en: count == 1 ? '1 step' : '$count steps',
        tr: '$count adım',
        es: count == 1 ? '1 paso' : '$count pasos',
        fr: count == 1 ? '1 étape' : '$count étapes',
        de: count == 1 ? '1 Schritt' : '$count Schritte',
      ));

  String planSummary(int tasks, int minutes) =>
      '${taskCount(tasks)} · ${minutesShort(minutes)}';

  String remainingLabel(String time) => l10n(lang, _m(
        en: '$time remaining',
        tr: '$time kaldı',
        es: '$time restante',
        fr: '$time restant',
        de: '$time verbleibend',
      ));

  String widgetPausedSubtitle(String remaining) => l10n(lang, _m(
        en: 'Paused · $remaining',
        tr: 'Duraklatıldı · $remaining',
        es: 'En pausa · $remaining',
        fr: 'En pause · $remaining',
        de: 'Pausiert · $remaining',
      ));

  String widgetActiveSubtitle(String remaining) => l10n(lang, _m(
        en: 'Active · $remaining left',
        tr: 'Aktif · $remaining kaldı',
        es: 'Activo · $remaining restante',
        fr: 'Actif · $remaining restant',
        de: 'Aktiv · $remaining verbleibend',
      ));

  String widgetNextSubtitle(String time) => '${nextUp} · $time';

  String durationTask(int minutes) => l10n(lang, _m(
        en: '$minutes minute task',
        tr: '$minutes dakikalık görev',
        es: 'Tarea de $minutes minutos',
        fr: 'Tâche de $minutes minutes',
        de: '$minutes-Minuten-Aufgabe',
      ));

  String deleteTaskConfirm(String title) => l10n(lang, _m(
        en: 'Delete "$title"?',
        tr: '"$title" silinsin mi?',
        es: '¿Eliminar "$title"?',
        fr: 'Supprimer « $title » ?',
        de: '"$title" löschen?',
      ));

  String tasksAddedToPlan(int count) => l10n(lang, _m(
        en: '$count tasks added to plan ✨',
        tr: '$count görev plana eklendi ✨',
        es: '$count tareas añadidas al plan ✨',
        fr: '$count tâches ajoutées au plan ✨',
        de: '$count Aufgaben zum Plan hinzugefügt ✨',
      ));

  String stepsTaskAdded(int count) => l10n(lang, _m(
        en: 'Task with $count steps added ✨',
        tr: '$count adımlı görev eklendi ✨',
        es: 'Tarea con $count pasos añadida ✨',
        fr: 'Tâche avec $count étapes ajoutée ✨',
        de: 'Aufgabe mit $count Schritten hinzugefügt ✨',
      ));

  String taskAdded(String title) => l10n(lang, _m(
        en: 'Added "$title" ✓',
        tr: '"$title" görevini ekledim ✓',
        es: 'Añadido "$title" ✓',
        fr: '« $title » ajouté ✓',
        de: '"$title" hinzugefügt ✓',
      ));

  String get sayTaskName => l10n(lang, _m(
        en: 'Say the task name.',
        tr: 'Görev adını söyle.',
        es: 'Di el nombre de la tarea.',
        fr: 'Dites le nom de la tâche.',
        de: 'Sag den Aufgabennamen.',
      ));

  String get taskAddFailed => l10n(lang, _m(
        en: 'Could not add task.',
        tr: 'Görev eklenemedi.',
        es: 'No se pudo añadir la tarea.',
        fr: 'Impossible d\'ajouter la tâche.',
        de: 'Aufgabe konnte nicht hinzugefügt werden.',
      ));

  String get taskAddRetry => l10n(lang, _m(
        en: 'Could not add task. Try again later.',
        tr: 'Görev eklenemedi. Biraz sonra tekrar dene.',
        es: 'No se pudo añadir la tarea. Inténtalo más tarde.',
        fr: 'Impossible d\'ajouter la tâche. Réessayez plus tard.',
        de: 'Aufgabe konnte nicht hinzugefügt werden. Später erneut versuchen.',
      ));

  // ADHD features
  String get overwhelmMode => l10n(lang, _m(en: 'Now mode', tr: 'Şimdi modu', es: 'Modo ahora', fr: 'Mode maintenant', de: 'Jetzt-Modus'));
  String get overwhelmModeHint => l10n(lang, _m(
        en: 'Show only current and next task',
        tr: 'Sadece şu anki ve sonraki görevi göster',
        es: 'Mostrar solo la tarea actual y la siguiente',
        fr: 'Afficher seulement la tâche actuelle et la suivante',
        de: 'Nur aktuelle und nächste Aufgabe anzeigen',
      ));
  String get nowLabel => l10n(lang, _m(en: 'Now', tr: 'Şimdi', es: 'Ahora', fr: 'Maintenant', de: 'Jetzt'));
  String get upNext => l10n(lang, _m(en: 'Up next', tr: 'Sırada', es: 'Siguiente', fr: 'À suivre', de: 'Als Nächstes'));
  String get brainDump => l10n(lang, _m(en: 'Brain dump', tr: 'Beyin dökümü', es: 'Volcado mental', fr: 'Décharge mentale', de: 'Gedanken abladen'));
  String get brainDumpHint => l10n(lang, _m(
        en: 'Pour everything out — AI will organize it',
        tr: 'Kafandaki her şeyi yaz — AI düzenlesin',
        es: 'Suelta todo — la IA lo organizará',
        fr: 'Déversez tout — l\'IA organisera',
        de: 'Schreib alles auf — die KI sortiert es',
      ));
  String get inboxTitle => l10n(lang, _m(en: 'Inbox', tr: 'Gelen kutusu', es: 'Bandeja', fr: 'Boîte de réception', de: 'Eingang'));
  String get inboxHint => l10n(lang, _m(
        en: 'Capture now, schedule later',
        tr: 'Şimdi kaydet, sonra planla',
        es: 'Captura ahora, planifica después',
        fr: 'Capturez maintenant, planifiez plus tard',
        de: 'Jetzt erfassen, später planen',
      ));
  String get addToInbox => l10n(lang, _m(en: 'Add to inbox', tr: 'Gelen kutusuna ekle', es: 'Añadir a bandeja', fr: 'Ajouter à la boîte', de: 'Zum Eingang hinzufügen'));
  String get emptyTodo => l10n(lang, _m(
        en: 'No to-dos yet',
        tr: 'Henüz yapılacak yok',
        es: 'Sin pendientes',
        fr: 'Aucune tâche',
        de: 'Noch keine Aufgaben',
      ));
  String get scheduleTask => l10n(lang, _m(en: 'Schedule', tr: 'Planla', es: 'Programar', fr: 'Planifier', de: 'Planen'));
  String get energyLevel => l10n(lang, _m(en: 'Energy needed', tr: 'Gerekli enerji', es: 'Energía necesaria', fr: 'Énergie requise', de: 'Benötigte Energie'));
  String get energyLow => l10n(lang, _m(en: 'Low', tr: 'Düşük', es: 'Baja', fr: 'Faible', de: 'Niedrig'));
  String get energyMedium => l10n(lang, _m(en: 'Medium', tr: 'Orta', es: 'Media', fr: 'Moyenne', de: 'Mittel'));
  String get energyHigh => l10n(lang, _m(en: 'High', tr: 'Yüksek', es: 'Alta', fr: 'Élevée', de: 'Hoch'));
  String get dailyEnergy => l10n(lang, _m(en: 'Today\'s energy', tr: 'Bugünkü enerjin', es: 'Energía de hoy', fr: 'Énergie du jour', de: 'Heutige Energie'));
  String get motivationWhy => l10n(lang, _m(en: 'Why does this matter?', tr: 'Bu neden önemli?', es: '¿Por qué importa?', fr: 'Pourquoi c\'est important ?', de: 'Warum ist das wichtig?'));
  String get transitionBuffer => l10n(lang, _m(en: 'Transition buffer', tr: 'Geçiş süresi', es: 'Tiempo de transición', fr: 'Tampon de transition', de: 'Übergangspuffer'));
  String get routineTemplates => l10n(lang, _m(en: 'Routine templates', tr: 'Rutin şablonları', es: 'Plantillas de rutina', fr: 'Modèles de routine', de: 'Routine-Vorlagen'));
  String get quickPresets => l10n(lang, _m(en: 'Quick presets', tr: 'Hızlı ekle', es: 'Accesos rápidos', fr: 'Raccourcis', de: 'Schnellvorlagen'));
  String get breakTime => l10n(lang, _m(en: 'Break time', tr: 'Mola zamanı', es: 'Descanso', fr: 'Pause', de: 'Pause'));
  String get breakHint => l10n(lang, _m(
        en: 'Great job! Take a breather before the next task.',
        tr: 'Harika! Sonraki göreve geçmeden önce dinlen.',
        es: '¡Bien hecho! Descansa antes de la siguiente tarea.',
        fr: 'Bravo ! Reposez-vous avant la prochaine tâche.',
        de: 'Super! Mach eine Pause vor der nächsten Aufgabe.',
      ));
  String get skipBreak => l10n(lang, _m(en: 'Skip break', tr: 'Molayı atla', es: 'Saltar descanso', fr: 'Passer la pause', de: 'Pause überspringen'));
  String get bodyDoubling => l10n(lang, _m(en: 'Body doubling', tr: 'Birlikte çalış', es: 'Compañía virtual', fr: 'Travail en duo', de: 'Gemeinsam fokussieren'));
  String get bodyDoublingHint => l10n(lang, _m(
        en: 'You\'re not alone — others are focusing right now too',
        tr: 'Yalnız değilsin — başkaları da şu an odaklanıyor',
        es: 'No estás solo — otros también se concentran ahora',
        fr: 'Vous n\'êtes pas seul — d\'autres se concentrent aussi',
        de: 'Du bist nicht allein — andere fokussieren sich gerade auch',
      ));
  String get scheduleWarning => l10n(lang, _m(en: 'Schedule check', tr: 'Plan kontrolü', es: 'Revisión del plan', fr: 'Vérification du planning', de: 'Planprüfung'));
  String scheduleOverlap(String a, String b, int min) => l10n(lang, _m(
        en: '$a and $b overlap by $min min',
        tr: '$a ve $b $min dk çakışıyor',
        es: '$a y $b se solapan $min min',
        fr: '« $a » et « $b » se chevauchent de $min min',
        de: '„$a“ und „$b“ überlappen um $min Min.',
      ));
  String scheduleTight(String a, String b) => l10n(lang, _m(
        en: 'Only a few minutes between $a and $b',
        tr: '$a ile $b arasında çok az süre var',
        es: 'Pocos minutos entre $a y $b',
        fr: 'Peu de temps entre « $a » et « $b »',
        de: 'Wenig Zeit zwischen „$a“ und „$b“',
      ));
  String get weeklyRetro => l10n(lang, _m(en: 'Weekly review', tr: 'Haftalık özet', es: 'Resumen semanal', fr: 'Bilan hebdomadaire', de: 'Wochenrückblick'));
  String weeklyRetroSummary(int tasks, int perfect, String peak) => l10n(lang, _m(
        en: '$tasks tasks done · $perfect great days · peak focus: $peak',
        tr: '$tasks görev tamamlandı · $perfect harika gün · en odaklı saat: $peak',
        es: '$tasks tareas · $perfect días geniales · pico: $peak',
        fr: '$tasks tâches · $perfect super jours · pic : $peak',
        de: '$tasks Aufgaben · $perfect starke Tage · Fokus-Spitze: $peak',
      ));
  String get onboardingWelcome => l10n(lang, _m(en: 'Welcome to Florien', tr: 'Florien\'ya hoş geldin', es: 'Bienvenido a Florien', fr: 'Bienvenue sur Florien', de: 'Willkommen bei Florien'));
  String get onboardingSubtitle => l10n(lang, _m(
        en: 'A gentle planner built for neurodivergent minds',
        tr: 'Nöroçeşitli zihinler için nazik bir planlayıcı',
        es: 'Un planificador amable para mentes neurodivergentes',
        fr: 'Un planificateur bienveillant pour les esprits neurodivergents',
        de: 'Ein sanfter Planer für neurodivergente Köpfe',
      ));
  String get onboardingThemePref => l10n(lang, _m(
        en: 'Light or dark mode?',
        tr: 'Açık mı koyu mod mu?',
        es: '¿Modo claro u oscuro?',
        fr: 'Mode clair ou sombre ?',
        de: 'Hell- oder Dunkelmodus?',
      ));
  String get onboardingThemeSubtitle => l10n(lang, _m(
        en: 'Pick what feels easiest on your eyes. You can change this anytime in settings.',
        tr: 'Gözüne en rahat geleni seç. İstediğin zaman ayarlardan değiştirebilirsin.',
        es: 'Elige lo que sea más cómodo para tus ojos. Puedes cambiarlo en ajustes.',
        fr: 'Choisissez ce qui repose le plus vos yeux. Modifiable à tout moment dans les réglages.',
        de: 'Wähle, was sich am angenehmsten anfühlt. Jederzeit in den Einstellungen änderbar.',
      ));
  String get onboardingViewPref => l10n(lang, _m(en: 'How do you like to see your day?', tr: 'Gününü nasıl görmek istersin?', es: '¿Cómo prefieres ver tu día?', fr: 'Comment voir votre journée ?', de: 'Wie möchtest du deinen Tag sehen?'));
  String get onboardingReminderPref => l10n(lang, _m(en: 'Reminder style', tr: 'Hatırlatıcı tercihi', es: 'Estilo de recordatorio', fr: 'Style de rappel', de: 'Erinnerungsstil'));
  String get onboardingRewardsPref => l10n(lang, _m(en: 'Enable rewards & celebrations?', tr: 'Ödül ve kutlamalar açık olsun mu?', es: '¿Activar recompensas?', fr: 'Activer récompenses et fêtes ?', de: 'Belohnungen aktivieren?'));
  String get getStarted => l10n(lang, _m(en: 'Get started', tr: 'Başla', es: 'Empezar', fr: 'Commencer', de: 'Los geht\'s'));
  String get nextStep => l10n(lang, _m(en: 'Next', tr: 'İleri', es: 'Siguiente', fr: 'Suivant', de: 'Weiter'));
  String get focusBlocking => l10n(lang, _m(en: 'Distraction blocking', tr: 'Dikkat engelleme', es: 'Bloqueo de distracciones', fr: 'Blocage des distractions', de: 'Ablenkungssperre'));
  String get focusBlockingHint => l10n(lang, _m(
        en: 'Before focusing, enable Do Not Disturb or app limits on your device.',
        tr: 'Odaklanmadan önce cihazında Rahatsız Etmeyin veya uygulama sınırını aç.',
        es: 'Antes de enfocarte, activa No molestar o límites de apps.',
        fr: 'Avant de vous concentrer, activez Ne pas déranger ou les limites d\'apps.',
        de: 'Vor dem Fokus: Bitte nicht stören oder App-Limits aktivieren.',
      ));
  String get openSettings => l10n(lang, _m(en: 'Open device settings', tr: 'Cihaz ayarlarını aç', es: 'Abrir ajustes', fr: 'Ouvrir les réglages', de: 'Geräteeinstellungen öffnen'));
  String get notificationSettings => l10n(lang, _m(en: 'Notification settings', tr: 'Bildirim ayarları', es: 'Ajustes de notificaciones', fr: 'Paramètres de notification', de: 'Benachrichtigungseinstellungen'));
  String get achievementUnlocked => l10n(lang, _m(en: 'Achievement unlocked!', tr: 'Rozet kazanıldı!', es: '¡Logro desbloqueado!', fr: 'Succès débloqué !', de: 'Erfolg freigeschaltet!'));
  String get breakAfterFocus => l10n(lang, _m(
        en: 'Break after focus',
        tr: 'Odak sonrası mola',
        es: 'Descanso tras enfocar',
        fr: 'Pause après focus',
        de: 'Pause nach Fokus',
      ));
  String get startRewardTimer => l10n(lang, _m(
        en: 'Start reward timer',
        tr: 'Ödül zamanlayıcısını başlat',
        es: 'Iniciar temporizador de recompensa',
        fr: 'Lancer le minuteur récompense',
        de: 'Belohnungs-Timer starten',
      ));
  String get rewardTimerActive => l10n(lang, _m(en: 'Enjoy your reward!', tr: 'Ödülünün tadını çıkar!', es: '¡Disfruta tu recompensa!', fr: 'Profitez de votre récompense !', de: 'Genieß deine Belohnung!'));
  String get movedToTomorrow => l10n(lang, _m(en: 'Moved to another time', tr: 'Başka bir zamana taşındı', es: 'Movido a otro momento', fr: 'Reporté à un autre moment', de: 'Auf später verschoben'));
  String get notDoneYet => l10n(lang, _m(en: 'Not done yet', tr: 'Henüz yapılmadı', es: 'Aún no hecho', fr: 'Pas encore fait', de: 'Noch nicht erledigt'));
  String energyLabel(EnergyLevel level) => switch (level) {
        EnergyLevel.low => energyLow,
        EnergyLevel.medium => energyMedium,
        EnergyLevel.high => energyHigh,
      };

  String friendlyTaskActionError(Object e) {
    if (e is FirebaseAuthException) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return sessionExpired;
      }
      return e.message ?? e.code;
    }
    final msg = e.toString();
    if (msg.contains('Task not found')) {
      return l10n(lang, _m(
        en: 'Task not found.',
        tr: 'Görev bulunamadı.',
        es: 'Tarea no encontrada.',
        fr: 'Tâche introuvable.',
        de: 'Aufgabe nicht gefunden.',
      ));
    }
    if (msg.contains('connection') || msg.contains('SocketException') || msg.contains('network')) {
      return serverUnreachable;
    }
    return friendlyAiError(e);
  }

  String friendlyAiError(Object e, {bool includeBootRunHint = false}) {
    if (e is FirebaseAuthException) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return sessionExpired;
      }
      return e.message ?? e.code;
    }
    final msg = e.toString();
    if (msg.contains('unauthenticated') || msg.contains('permission-denied')) {
      return includeBootRunHint ? aiRequestDeniedWithHint : aiRequestDenied;
    }
    if (msg.contains('Groq') || msg.contains('GROQ')) return groqUnavailable;
    if (msg.contains('connection') || msg.contains('SocketException') || msg.contains('network')) {
      return serverUnreachable;
    }
    return msg
        .replaceFirst('Exception: ', '')
        .replaceFirst('FirebaseFunctionsException: ', '');
  }
}

Map<String, String> _m({
  required String en,
  required String tr,
  required String es,
  required String fr,
  required String de,
}) =>
    {'en': en, 'tr': tr, 'es': es, 'fr': fr, 'de': de};

final stringsProvider = Provider<S>((ref) {
  final lang = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
  return S(lang);
});
