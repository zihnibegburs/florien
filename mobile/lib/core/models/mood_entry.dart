enum MoodLevel { veryLow, low, neutral, good, veryGood }

extension MoodLevelDetails on MoodLevel {
  String get label => switch (this) {
    MoodLevel.veryLow => 'Çok zor',
    MoodLevel.low => 'Zor',
    MoodLevel.neutral => 'Dengede',
    MoodLevel.good => 'İyi',
    MoodLevel.veryGood => 'Çok iyi',
  };

  String get emoji => switch (this) {
    MoodLevel.veryLow => '😞',
    MoodLevel.low => '😕',
    MoodLevel.neutral => '😐',
    MoodLevel.good => '🙂',
    MoodLevel.veryGood => '😄',
  };

  double get valence => switch (this) {
    MoodLevel.veryLow => -1,
    MoodLevel.low => -.5,
    MoodLevel.neutral => 0,
    MoodLevel.good => .5,
    MoodLevel.veryGood => 1,
  };

  static MoodLevel fromValence(double value) {
    if (value <= -.75) return MoodLevel.veryLow;
    if (value <= -.25) return MoodLevel.low;
    if (value < .25) return MoodLevel.neutral;
    if (value < .75) return MoodLevel.good;
    return MoodLevel.veryGood;
  }
}

class MoodEntry {
  const MoodEntry({
    required this.date,
    required this.mood,
    this.reflection = '',
    this.healthSynced = false,
  });

  final DateTime date;
  final MoodLevel mood;
  final String reflection;
  final bool healthSynced;

  DateTime get day => DateTime(date.year, date.month, date.day);

  MoodEntry copyWith({
    DateTime? date,
    MoodLevel? mood,
    String? reflection,
    bool? healthSynced,
  }) => MoodEntry(
    date: date ?? this.date,
    mood: mood ?? this.mood,
    reflection: reflection ?? this.reflection,
    healthSynced: healthSynced ?? this.healthSynced,
  );

  Map<String, dynamic> toJson() => {
    'date': day.toIso8601String(),
    'mood': mood.name,
    'reflection': reflection,
    'healthSynced': healthSynced,
  };

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    final moodName = json['mood'] as String?;
    final mood = MoodLevel.values.where((item) => item.name == moodName);
    if (date == null || mood.isEmpty) {
      throw const FormatException('Geçersiz ruh hali kaydı.');
    }
    return MoodEntry(
      date: DateTime(date.year, date.month, date.day),
      mood: mood.first,
      reflection: json['reflection'] as String? ?? '',
      healthSynced: json['healthSynced'] as bool? ?? false,
    );
  }
}
