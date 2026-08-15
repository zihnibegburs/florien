import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';

Future<void> showCompletionCelebration(
  BuildContext context,
  CompletionCounts counts,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => CompletionCelebrationScreen(counts: counts),
  ),
);

class CompletionCelebrationScreen extends StatefulWidget {
  const CompletionCelebrationScreen({super.key, required this.counts});

  final CompletionCounts counts;

  @override
  State<CompletionCelebrationScreen> createState() =>
      _CompletionCelebrationScreenState();
}

class _CompletionCelebrationScreenState
    extends State<CompletionCelebrationScreen> {
  bool _showWeek = false;

  int get _count => _showWeek ? widget.counts.thisWeek : widget.counts.today;

  String get _period => _showWeek ? 'Bu hafta' : 'Bugün';

  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(text: '$_period $_count görev tamamladım 🎉'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Başarı özeti panoya kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('completion-celebration-page'),
    backgroundColor: context.palette.background,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: _share,
                  child: const Text('Paylaş'),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: FlorienColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.palette.border,
                            width: FlorienBorders.thin,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: FlorienColors.onPrimary,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 34),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          '$_period\n$_count görev tamamladınız 🎉',
                          key: ValueKey('completion-count-$_showWeek-$_count'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.18,
                                letterSpacing: -.6,
                              ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Harika gidiyorsunuz. Küçük adımlar büyük bir ritim oluşturur.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Bugün')),
                          ButtonSegment(value: true, label: Text('Bu hafta')),
                        ],
                        selected: {_showWeek},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) =>
                            setState(() => _showWeek = selection.first),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
