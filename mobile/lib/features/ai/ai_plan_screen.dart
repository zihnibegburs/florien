import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/ai_models.dart';
import 'package:mimio/core/repositories/ai_repository.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/copyable_error_banner.dart';
import 'package:mimio/core/widgets/speech_text_field.dart';
import 'package:mimio/core/utils/task_icons.dart';
import 'package:mimio/features/providers.dart';
import 'package:mimio/features/timeline/home_tab.dart';

enum AiMode { breakdown, plan }

final aiModeProvider = StateProvider<AiMode>((ref) => AiMode.plan);

class AiPlanScreen extends ConsumerStatefulWidget {
  const AiPlanScreen({super.key});

  @override
  ConsumerState<AiPlanScreen> createState() => _AiPlanScreenState();
}

class _AiPlanScreenState extends ConsumerState<AiPlanScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _applying = false;
  AiBreakdownModel? _breakdown;
  AiPlanModel? _plan;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _breakdown = null;
      _plan = null;
    });

    try {
      final mode = ref.read(aiModeProvider);
      if (mode == AiMode.breakdown) {
        final result = await ref.read(aiRepositoryProvider).breakdown(text);
        setState(() => _breakdown = result);
      } else {
        final date = ref.read(selectedDateProvider);
        final result = await ref.read(aiRepositoryProvider).plan(
              'Organize this brain dump into a realistic daily schedule with breaks:\n$text',
              date: date,
            );
        setState(() => _plan = result);
      }
    } catch (e) {
      final s = ref.read(stringsProvider);
      setState(() => _error = _friendlyError(e, s));
    } finally {
      setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e, S s) {
    return s.friendlyAiError(e);
  }

  Future<void> _applyPlan() async {
    if (_plan == null || _applying) return;

    setState(() {
      _applying = true;
      _error = null;
    });

    try {
      for (final task in _plan!.tasks) {
        await ref.read(timelineProvider.notifier).createTask(
              title: task.title,
              durationMinutes: task.durationMinutes,
              color: task.color,
              icon: TaskIcons.inferName(task.title),
              scheduledAt: task.scheduledAt(_plan!.date),
              autoStart: false,
            );
      }
      if (!mounted) return;
      final s = ref.read(stringsProvider);
      ref.read(homeTabProvider.notifier).state = HomeTab.today;
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.tasksAddedToPlan(_plan!.tasks.length))),
      );
    } catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        setState(() => _error = _friendlyError(e, s));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _applyBreakdown() async {
    if (_breakdown == null || _applying) return;

    setState(() {
      _applying = true;
      _error = null;
    });

    try {
      final date = ref.read(selectedDateProvider);
      var hour = DateTime.now().hour;
      var minute = 0;
      if (hour < 8) {
        hour = 8;
      }
      final scheduledAt = DateTime(date.year, date.month, date.day, hour, minute);

      await ref.read(timelineProvider.notifier).createTaskWithSubtasks(
            title: _breakdown!.originalTask,
            scheduledAt: scheduledAt,
            color: _breakdown!.steps.first.color,
            subtasks: _breakdown!.steps
                .map((s) => (title: s.title, durationMinutes: s.durationMinutes, color: s.color))
                .toList(),
            autoStart: false,
          );

      if (!mounted) return;
      final s = ref.read(stringsProvider);
      ref.read(homeTabProvider.notifier).state = HomeTab.today;
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.stepsTaskAdded(_breakdown!.steps.length))),
      );
    } catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        setState(() => _error = _friendlyError(e, s));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(aiModeProvider);
    final s = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(s.aiPlanner),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  _ModeChip(
                    label: s.planDay,
                    icon: Icons.auto_awesome_rounded,
                    selected: mode == AiMode.plan,
                    onTap: () => ref.read(aiModeProvider.notifier).state = AiMode.plan,
                  ),
                  _ModeChip(
                    label: s.splitTask,
                    icon: Icons.checklist_rounded,
                    selected: mode == AiMode.breakdown,
                    onTap: () => ref.read(aiModeProvider.notifier).state = AiMode.breakdown,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              mode == AiMode.plan ? s.planPrompt : s.breakdownPrompt,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              mode == AiMode.plan ? s.planExample : s.breakdownExample,
              style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SpeechTextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: mode == AiMode.plan ? s.planHint : s.breakdownHint,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? s.aiThinking : s.createPlan),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              CopyableErrorBanner(message: _error!),
            ],
            if (_plan != null) ...[
              const SizedBox(height: 24),
              _ResultHeader(
                title: _plan!.summary,
                subtitle: s.planSummary(_plan!.tasks.length, _plan!.totalMinutes),
              ),
              ..._plan!.tasks.map((t) => _TaskResultTile(
                    title: t.title,
                    subtitle: '${t.suggestedTime} · ${s.minutesShort(t.durationMinutes)}',
                    color: MimioColors.fromHex(t.color),
                  )),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _applying ? null : _applyPlan,
                icon: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.calendar_today_rounded),
                label: Text(_applying ? s.saving : s.addPlanToDay),
                style: ElevatedButton.styleFrom(backgroundColor: MimioColors.success),
              ),
            ],
            if (_breakdown != null) ...[
              const SizedBox(height: 24),
              _ResultHeader(
                title: _breakdown!.originalTask,
                subtitle: '${s.stepsCount(_breakdown!.steps.length)} · ${s.minutesShort(_breakdown!.totalMinutes)}',
              ),
              ..._breakdown!.steps.asMap().entries.map((e) => _TaskResultTile(
                    title: '${e.key + 1}. ${e.value.title}',
                    subtitle: s.minutesShort(e.value.durationMinutes),
                    color: MimioColors.fromHex(e.value.color),
                  )),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _applying ? null : _applyBreakdown,
                icon: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_task_rounded),
                label: Text(_applying ? s.saving : s.addTaskAndSteps),
                style: ElevatedButton.styleFrom(backgroundColor: MimioColors.success),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              s.poweredByGroq,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? MimioColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : context.palette.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MimioColors.primary.withValues(alpha: 0.15), MimioColors.primaryLight.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: context.palette.textSecondary)),
        ],
      ),
    );
  }
}

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
