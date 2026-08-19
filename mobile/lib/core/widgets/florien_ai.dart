import 'package:flutter/material.dart';
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
    this.hintText = 'Ne yapmak istiyorsun?',
    this.inputKey,
    this.sendKey,
    this.voiceKey,
    this.onVoiceTap,
    this.isListening = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final String hintText;
  final Key? inputKey;
  final Key? sendKey;
  final Key? voiceKey;
  final VoidCallback? onVoiceTap;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlorienSpacing.screen,
        FlorienSpacing.sm,
        FlorienSpacing.screen,
        FlorienSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(FlorienRadius.xl),
          border: Border.all(
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: inputKey,
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                minLines: 1,
                maxLines: 4,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (onVoiceTap != null) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: voiceKey,
                  onTap: enabled ? onVoiceTap : null,
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
                        ? const Padding(
                            padding: EdgeInsets.all(3),
                            child: FlorienAiAnimation(
                              size: 40,
                              speed: 1.4,
                              animate: true,
                              semanticLabel: 'Sesli AI aktif',
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
                onTap: enabled ? onSend : null,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? FlorienColors.primary
                        : context.palette.surfaceMuted,
                    border: Border.all(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: enabled
                        ? FlorienColors.onPrimary
                        : context.palette.textSecondary,
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
