class AiStepModel {
  final String title;
  final int durationMinutes;
  final String color;

  const AiStepModel({
    required this.title,
    required this.durationMinutes,
    required this.color,
  });

  factory AiStepModel.fromJson(Map<String, dynamic> json) => AiStepModel(
        title: json['title'] as String,
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        color: json['color'] as String? ?? '#3D9B87',
      );
}

class AiBreakdownModel {
  final String originalTask;
  final List<AiStepModel> steps;
  final int totalMinutes;

  const AiBreakdownModel({
    required this.originalTask,
    required this.steps,
    required this.totalMinutes,
  });

  factory AiBreakdownModel.fromJson(Map<String, dynamic> json) => AiBreakdownModel(
        originalTask: json['originalTask'] as String,
        steps: (json['steps'] as List)
            .map((s) => AiStepModel.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
        totalMinutes: (json['totalMinutes'] as num).toInt(),
      );
}

class AiPlannedTaskModel {
  final String title;
  final int durationMinutes;
  final String suggestedTime;
  final String color;

  const AiPlannedTaskModel({
    required this.title,
    required this.durationMinutes,
    required this.suggestedTime,
    required this.color,
  });

  factory AiPlannedTaskModel.fromJson(Map<String, dynamic> json) => AiPlannedTaskModel(
        title: json['title'] as String,
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        suggestedTime: json['suggestedTime'] as String,
        color: json['color'] as String? ?? '#3D9B87',
      );

  DateTime scheduledAt(DateTime date) {
    final parts = suggestedTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

class AiPlanModel {
  final DateTime date;
  final String summary;
  final List<AiPlannedTaskModel> tasks;
  final int totalMinutes;

  const AiPlanModel({
    required this.date,
    required this.summary,
    required this.tasks,
    required this.totalMinutes,
  });

  factory AiPlanModel.fromJson(Map<String, dynamic> json) => AiPlanModel(
        date: DateTime.parse(json['date'] as String),
        summary: json['summary'] as String,
        tasks: (json['tasks'] as List)
            .map((t) => AiPlannedTaskModel.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        totalMinutes: (json['totalMinutes'] as num).toInt(),
      );
}
