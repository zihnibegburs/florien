import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/liquid_glass.dart';
import 'package:mimio/features/focus/widgets/focus_timer_widget.dart';
import 'package:mimio/features/timeline/home_tab.dart';

class ActiveTaskBanner extends ConsumerWidget {
  const ActiveTaskBanner({super.key, required this.session});

  final FocusSessionModel session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final color = MimioColors.fromHex(session.color);

    return GestureDetector(
      onTap: () => ref.read(homeTabProvider.notifier).state = HomeTab.focus,
      child: LiquidGlass(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        borderRadius: BorderRadius.circular(24),
        blur: true,
        blurSigma: 20,
        padding: const EdgeInsets.all(16),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.92), color.withValues(alpha: 0.72)],
        ),
        tintOpacity: 0.15,
        child: Row(
          children: [
            FocusTimerWidget(
              session: session,
              size: 72,
              showLabel: false,
              inverted: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.isActive ? s.currentlyActive : s.paused,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    session.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    s.remainingLabel(session.remainingFormatted),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
