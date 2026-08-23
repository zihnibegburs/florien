import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_ai_animation.dart';

class FlorienAiMessageBubble extends StatelessWidget {
  const FlorienAiMessageBubble({
    super.key,
    required this.child,
    this.isUser = false,
  });

  final Widget child;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.only(bottom: FlorienSpacing.md),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(FlorienRadius.lg),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: child,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: FlorienSpacing.md),
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
          gradient: FlorienColors.aiGradient,
        ),
        child: Container(
          padding: const EdgeInsets.all(FlorienSpacing.lg),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.lg - 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class FlorienAiInput extends StatelessWidget {
  const FlorienAiInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.textEnabled,
    this.premiumLocked = false,
    this.onPremiumTap,
    this.hintText = 'Ne yapmak istiyorsun?',
    this.inputKey,
    this.sendKey,
    this.voiceKey,
    this.onVoiceTap,
    this.isListening = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// Send and voice actions (TextField stays tappable when false).
  final bool enabled;

  /// When null, follows [enabled]. Set true to keep the field editable while
  /// actions stay disabled (e.g. free monthly quota exhausted).
  final bool? textEnabled;

  /// Free quota exhausted — field read-only, premium affordance on send.
  final bool premiumLocked;
  final VoidCallback? onPremiumTap;
  final String hintText;
  final Key? inputKey;
  final Key? sendKey;
  final Key? voiceKey;
  final VoidCallback? onVoiceTap;
  final bool isListening;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final canType = premiumLocked ? false : (textEnabled ?? enabled);
    final actionsEnabled = premiumLocked ? false : enabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlorienSpacing.screen,
        FlorienSpacing.sm,
        FlorienSpacing.screen,
        FlorienSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(FlorienRadius.xl),
              border: Border.all(
                color: premiumLocked
                    ? FlorienColors.aiAccent.withValues(alpha: 0.45)
                    : context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: premiumLocked
                      ? GestureDetector(
                          key: inputKey,
                          onTap: onPremiumTap,
                          behavior: HitTestBehavior.opaque,
                          child: IgnorePointer(
                            child: TextField(
                              controller: controller,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: hintText,
                                hintStyle: TextStyle(
                                  color: context.palette.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                            ),
                          ),
                        )
                      : TextField(
                          key: inputKey,
                          controller: controller,
                          enabled: canType,
                          readOnly: !canType,
                          textInputAction: TextInputAction.send,
                          onSubmitted: canType && actionsEnabled
                              ? (_) => onSend()
                              : null,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: maxLength,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => const SizedBox.shrink(),
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(
                              color: context.palette.textSecondary,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                if (onVoiceTap != null && !premiumLocked) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: voiceKey,
                      onTap: actionsEnabled ? onVoiceTap : null,
                      customBorder: const CircleBorder(),
                      child: Ink(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isListening || context.isFlorienDark
                              ? FlorienColors.aiGradient
                              : null,
                          color: isListening || context.isFlorienDark
                              ? null
                              : context.palette.aiSurface,
                          border: Border.all(
                            color: context.palette.border,
                            width: FlorienBorders.thin,
                          ),
                        ),
                        child: isListening
                            ? Padding(
                                padding: const EdgeInsets.all(3),
                                child: FlorienAiAnimation(
                                  size: 40,
                                  speed: 1.4,
                                  animate: true,
                                  semanticLabel: context.l10n('Sesli AI aktif'),
                                ),
                              )
                            : const Icon(
                                Icons.graphic_eq_rounded,
                                color: FlorienColors.onPrimary,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: sendKey,
                    onTap: premiumLocked
                        ? onPremiumTap
                        : (actionsEnabled ? onSend : null),
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: premiumLocked
                            ? FlorienColors.aiGradient
                            : null,
                        color: premiumLocked
                            ? null
                            : (actionsEnabled
                                  ? FlorienColors.primary
                                  : context.palette.surfaceMuted),
                        border: Border.all(
                          color: context.palette.border,
                          width: FlorienBorders.thin,
                        ),
                      ),
                      child: Icon(
                        premiumLocked
                            ? Icons.workspace_premium_rounded
                            : Icons.arrow_upward_rounded,
                        color: premiumLocked || actionsEnabled
                            ? FlorienColors.onPrimary
                            : context.palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (maxLength != null && !premiumLocked)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final used = controller.text.runes.length;
                final showFrom = (maxLength! * 0.8).ceil();
                if (used < showFrom) return const SizedBox.shrink();
                final atLimit = used >= maxLength!;
                return Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$used / $maxLength',
                      key: const ValueKey('planner-ai-char-count'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: atLimit
                            ? context.palette.error
                            : context.palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
