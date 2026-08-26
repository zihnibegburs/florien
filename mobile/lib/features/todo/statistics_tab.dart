import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/mood_entry.dart';
import 'package:florien/core/services/review_feedback_service.dart';
import 'package:florien/core/services/store_review.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/achievement_collection.dart';
import 'package:florien/features/todo/profile_management_screen.dart';
import 'package:florien/features/todo/settings_screen.dart';

/// Insights / statistics tab inspired by the reference layout.
class StatisticsTab extends ConsumerWidget {
  const StatisticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(completionCountsProvider);
    final authName = ref.watch(
      authStateProvider.select((value) => value.valueOrNull?.firstName),
    );
    final profileName = ref.watch(activeAppProfileProvider)?.name;
    final name = profileName?.isNotEmpty == true
        ? profileName!
        : (authName == null || authName.isEmpty ? 'Florien' : authName);
    final week = counts.valueOrNull?.thisWeek ?? 0;
    final streak = counts.valueOrNull?.streak ?? 0;
    final completedGoal = 30;
    final completed = week.clamp(0, completedGoal);

    return ColoredBox(
      color: context.palette.background,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const ValueKey('statistics-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FlorienSpacing.screen,
                  FlorienSpacing.md,
                  FlorienSpacing.screen,
                  0,
                ),
                child: _StatsHeader(
                  name: name,
                  onProfileTap: () => showProfileSwitcher(context, ref),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxl),
            ),
            const SliverToBoxAdapter(child: AchievementSection()),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxl),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.screen,
                ),
                child: _StatsSummaryCard(
                  streak: streak,
                  completed: completed,
                  completedGoal: completedGoal,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxxl),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.screen,
                ),
                child: _MoodSection(),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: FlorienSpacing.xxxl),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: FlorienSpacing.screen,
                ),
                child: StatisticsReviewCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.name, required this.onProfileTap});

  final String name;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          child: InkWell(
            key: const ValueKey('statistics-profile-switcher'),
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 11, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FlorienRadius.pill),
                border: Border.all(
                  color: context.palette.border,
                  width: FlorienBorders.thin,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _RoundHeaderButton(
          tooltip: context.l10n('Paylaş'),
          icon: Icons.ios_share_rounded,
          onPressed: () {},
        ),
        const SizedBox(width: 10),
        _RoundHeaderButton(
          tooltip: context.l10n('Ayarlar'),
          icon: Icons.settings_outlined,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.palette.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(dimension: 44, child: Icon(icon, size: 20)),
        ),
      ),
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({
    required this.streak,
    required this.completed,
    required this.completedGoal,
  });

  final int streak;
  final int completed;
  final int completedGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.xxl),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                value: '$streak',
                label: context.l10n('GÜN SERİSİ'),
                progressLabel: streak == 1
                    ? context.l10n('1 gün')
                    : '$streak gün',
                progress: (streak / 7).clamp(0, 1),
                accent: FlorienColors.accent,
                icon: Icons.local_fire_department_rounded,
              ),
            ),
            VerticalDivider(
              width: 28,
              thickness: FlorienBorders.thin,
              color: context.palette.border.withValues(alpha: 0.35),
            ),
            Expanded(
              child: _StatColumn(
                value: '$completed',
                label: context.l10n('TAMAMLANDI'),
                progressLabel: context.l10n('{completed}/{goal} görevler', {
                  'completed': '$completed',
                  'goal': '$completedGoal',
                }),
                progress: completed / completedGoal,
                accent: FlorienColors.mint,
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.progressLabel,
    required this.progress,
    required this.accent,
    required this.icon,
  });

  final String value;
  final String label;
  final String progressLabel;
  final double progress;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Icon(icon, color: FlorienColors.onPrimary),
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: context.palette.surfaceMuted,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          progressLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

typedef ReviewStoreOpener = Future<bool> Function();
typedef ReviewFeedbackSubmitter =
    Future<void> Function(int rating, String issue, String suggestion);

class StatisticsReviewCard extends StatefulWidget {
  const StatisticsReviewCard({super.key, this.openStore, this.submitFeedback});

  final ReviewStoreOpener? openStore;
  final ReviewFeedbackSubmitter? submitFeedback;

  @override
  State<StatisticsReviewCard> createState() => _StatisticsReviewCardState();
}

class _StatisticsReviewCardState extends State<StatisticsReviewCard> {
  int _rating = 0;
  bool _openingStore = false;

  Future<void> _selectRating(int rating) async {
    if (_openingStore) return;
    setState(() => _rating = rating);

    final openStore = await _showThankYouDialog(rating);
    if (!mounted || openStore != true) return;

    await _openStore();
  }

  Future<bool?> _showThankYouDialog(int rating) async {
    if (rating <= 3) {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _LowRatingFeedbackDialog(rating: rating, onSubmit: _submitFeedback),
      );
      if (submitted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n('Geri bildirimin bize ulaştı. Teşekkür ederiz!'),
            ),
          ),
        );
      }
      return false;
    }
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          key: const ValueKey('statistics-rating-thanks-dialog'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.medium,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: context.palette.selection,
                    borderRadius: BorderRadius.circular(FlorienRadius.md),
                    border: Border.all(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: FlorienColors.onPrimary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n('Teşekkürler!'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n(
                    'Florien’i mağazada değerlendirerek bize destek olmak ister misin?',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('statistics-rating-open-store'),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.l10n('Mağazada değerlendir')),
                  ),
                ),
                TextButton(
                  key: const ValueKey('statistics-rating-dismiss'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n('Şimdi değil')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitFeedback(int rating, String issue, String suggestion) {
    final submit = widget.submitFeedback;
    if (submit != null) return submit(rating, issue, suggestion);
    return ReviewFeedbackService().submit(
      rating: rating,
      issue: issue,
      suggestion: suggestion,
    );
  }

  Future<void> _openStore() async {
    setState(() => _openingStore = true);
    final opened = await (widget.openStore ?? openFlorienStoreReview)();
    if (!mounted) return;
    setState(() => _openingStore = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n('Mağaza şu anda açılamadı. Lütfen tekrar dene.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(FlorienRadius.lg),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: Column(
      children: [
        Text(
          context.l10n('Bizi değerlendirin'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n('Florien deneyimini kaç yıldızla değerlendirirsin?'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var rating = 1; rating <= 5; rating++) ...[
              Semantics(
                button: true,
                selected: rating <= _rating,
                label: context.l10n('{count} yıldız', {'count': '$rating'}),
                child: InkWell(
                  key: ValueKey('statistics-rating-$rating'),
                  onTap: _openingStore ? null : () => _selectRating(rating),
                  borderRadius: BorderRadius.circular(FlorienRadius.sm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: rating <= _rating
                          ? context.palette.selection
                          : context.palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(FlorienRadius.sm),
                      border: Border.all(
                        color: context.palette.border,
                        width: FlorienBorders.thin,
                      ),
                    ),
                    child: Icon(
                      rating <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: context.palette.textPrimary,
                      size: 27,
                    ),
                  ),
                ),
              ),
              if (rating < 5) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    ),
  );
}

class _LowRatingFeedbackDialog extends StatefulWidget {
  const _LowRatingFeedbackDialog({
    required this.rating,
    required this.onSubmit,
  });

  final int rating;
  final ReviewFeedbackSubmitter onSubmit;

  @override
  State<_LowRatingFeedbackDialog> createState() =>
      _LowRatingFeedbackDialogState();
}

class _LowRatingFeedbackDialogState extends State<_LowRatingFeedbackDialog> {
  final _issue = TextEditingController();
  final _suggestion = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _canSubmit =>
      _issue.text.trim().isNotEmpty || _suggestion.text.trim().isNotEmpty;

  @override
  void dispose() {
    _issue.dispose();
    _suggestion.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        widget.rating,
        _issue.text.trim(),
        _suggestion.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Review feedback could not be submitted: $error');
      if (mounted) {
        setState(() {
          _sending = false;
          _error = context.l10n(
            'Geri bildirimin gönderilemedi. Lütfen tekrar dene.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('statistics-rating-thanks-dialog'),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.forum_rounded,
            color: FlorienColors.aiAccent,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n('Teşekkürler!'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n(
              'Deneyimini iyileştirebilmemiz için bize biraz daha anlatır mısın?',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('statistics-rating-issue'),
            controller: _issue,
            minLines: 2,
            maxLines: 4,
            maxLength: reviewFeedbackMaxCharacters,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n('Yaşadığın sorun nedir?'),
              hintText: context.l10n('Örneğin: Görev eklerken zorlandım…'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('statistics-rating-suggestion'),
            controller: _suggestion,
            minLines: 2,
            maxLines: 4,
            maxLength: reviewFeedbackMaxCharacters,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n('Önerin nedir?'),
              hintText: context.l10n('Florien’i nasıl iyileştirebiliriz?'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: context.palette.error)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('statistics-rating-submit-feedback'),
            onPressed: _canSubmit && !_sending ? _submit : null,
            child: Text(
              _sending
                  ? context.l10n('Gönderiliyor…')
                  : context.l10n('Geri bildirimi gönder'),
            ),
          ),
          TextButton(
            key: const ValueKey('statistics-rating-dismiss'),
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: Text(context.l10n('Şimdi değil')),
          ),
        ],
      ),
    ),
  );
}

class _MoodSection extends ConsumerWidget {
  const _MoodSection();

  static const _dayKeys = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final weekStart = _weekStart(now);
    final today = DateTime(now.year, now.month, now.day);
    final entries = ref.watch(moodEntriesProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n('Ruh Hali ve Günlük Yansımalar'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _connectAppleHealth(context, ref),
              icon: const Icon(Icons.health_and_safety_outlined, size: 18),
              label: Text(context.l10n('Apple Sağlık')),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n('Bugün veya geçmiş günler için nasıl hissettiğini seç.'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: FlorienSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final date in List.generate(
              _dayKeys.length,
              (index) => weekStart.add(Duration(days: index)),
            ))
              _MoodDayButton(
                label: context.l10n(_dayKeys[date.weekday - DateTime.monday]),
                date: date,
                entry: _entryForDay(entries, date),
                isToday: _sameDay(today, date),
                enabled: !date.isAfter(today),
                onTap: date.isAfter(today)
                    ? null
                    : () => _editMood(
                        context,
                        ref,
                        date,
                        _entryForDay(entries, date),
                      ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _connectAppleHealth(BuildContext context, WidgetRef ref) async {
    final connected = await ref
        .read(moodEntriesProvider.notifier)
        .connectAppleHealth();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? context.l10n(
                  'Apple Sağlık bağlandı. Bu haftanın ruh halleri eşitlendi.',
                )
              : context.l10n(
                  'Apple Sağlık izni verilmedi veya bu iPhone desteklenmiyor.',
                ),
        ),
      ),
    );
  }

  Future<void> _editMood(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    MoodEntry? entry,
  ) async {
    if (date.isAfter(DateTime.now())) return;
    final updated = await showModalBottomSheet<MoodEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoodEntrySheet(date: date, entry: entry),
    );
    if (updated != null) {
      await ref.read(moodEntriesProvider.notifier).saveEntry(updated);
    }
  }
}

class _MoodDayButton extends StatelessWidget {
  const _MoodDayButton({
    required this.label,
    required this.date,
    required this.entry,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final MoodEntry? entry;
  final bool isToday;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mood = entry?.mood;
    final color = _moodColor(mood, context);
    return Semantics(
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: ValueKey(
                  'mood-day-${date.year}-${date.month}-${date.day}',
                ),
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: mood == null ? context.palette.surface : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday
                          ? context.palette.selection
                          : context.palette.border,
                      width: isToday
                          ? FlorienBorders.medium
                          : FlorienBorders.thin,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      mood?.emoji ?? (enabled ? '+' : '—'),
                      style: TextStyle(
                        fontSize: mood == null ? 22 : 19,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodEntrySheet extends StatefulWidget {
  const _MoodEntrySheet({required this.date, required this.entry});

  final DateTime date;
  final MoodEntry? entry;

  @override
  State<_MoodEntrySheet> createState() => _MoodEntrySheetState();
}

class _MoodEntrySheetState extends State<_MoodEntrySheet> {
  late MoodLevel _mood = widget.entry?.mood ?? MoodLevel.neutral;
  late final TextEditingController _reflection = TextEditingController(
    text: widget.entry?.reflection ?? '',
  );

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            moodReflectionQuestion(widget.date),
            key: const ValueKey('mood-reflection-question'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in MoodLevel.values)
                ChoiceChip(
                  label: Text('${mood.emoji} ${mood.label}'),
                  selected: _mood == mood,
                  selectedColor: _moodColor(mood, context),
                  onSelected: (_) => setState(() => _mood = mood),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('mood-reflection-input'),
            controller: _reflection,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.l10n(
                'Bugünle ilgili kısa bir yansıma ekle (isteğe bağlı)',
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                MoodEntry(
                  date: widget.date,
                  mood: _mood,
                  reflection: _reflection.text.trim(),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(context.l10n('Ruh halini kaydet')),
            ),
          ),
        ],
      ),
    ),
  );
}

MoodEntry? _entryForDay(List<MoodEntry> entries, DateTime date) {
  for (final entry in entries) {
    if (_sameDay(entry.date, date)) return entry;
  }
  return null;
}

DateTime _weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _localizedMonthName(int month) => [
  ActiveLanguage.s('Ocak'),
  ActiveLanguage.s('Şubat'),
  ActiveLanguage.s('Mart'),
  ActiveLanguage.s('Nisan'),
  ActiveLanguage.s('Mayıs'),
  ActiveLanguage.s('Haziran'),
  ActiveLanguage.s('Temmuz'),
  ActiveLanguage.s('Ağustos'),
  ActiveLanguage.s('Eylül'),
  ActiveLanguage.s('Ekim'),
  ActiveLanguage.s('Kasım'),
  ActiveLanguage.s('Aralık'),
][month - 1];

String _localizedWeekdayName(int weekday) => [
  ActiveLanguage.s('Pazartesi'),
  ActiveLanguage.s('Salı'),
  ActiveLanguage.s('Çarşamba'),
  ActiveLanguage.s('Perşembe'),
  ActiveLanguage.s('Cuma'),
  ActiveLanguage.s('Cumartesi'),
  ActiveLanguage.s('Pazar'),
][weekday - 1];

String moodReflectionQuestion(DateTime date, {DateTime? today}) {
  final current = today ?? DateTime.now();
  final currentDay = DateTime(current.year, current.month, current.day);
  final selectedDay = DateTime(date.year, date.month, date.day);
  if (_sameDay(selectedDay, currentDay)) {
    return ActiveLanguage.s('Bugün nasılsın?');
  }
  if (_sameDay(selectedDay, currentDay.subtract(const Duration(days: 1)))) {
    return ActiveLanguage.s('Dün nasıldın?');
  }

  final year = selectedDay.year == currentDay.year
      ? ''
      : ' ${selectedDay.year}';
  return ActiveLanguage.s('{day} {month}{year} {weekday} günü nasıldın?', {
    'day': '${selectedDay.day}',
    'month': _localizedMonthName(selectedDay.month),
    'year': year,
    'weekday': _localizedWeekdayName(selectedDay.weekday),
  });
}

Color _moodColor(MoodLevel? mood, BuildContext context) => switch (mood) {
  MoodLevel.veryLow => FlorienColors.softPink,
  MoodLevel.low => FlorienColors.warning,
  MoodLevel.neutral => context.palette.surfaceMuted,
  MoodLevel.good => FlorienColors.mint,
  MoodLevel.veryGood => FlorienColors.primary,
  null => context.palette.surface,
};
