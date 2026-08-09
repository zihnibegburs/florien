import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/liquid_glass.dart';

/// Shared soft overlay styling — light scrim, gentle fade+scale transitions.
abstract final class MimioOverlay {
  static final barrierColor = Colors.black.withValues(alpha: 0.18);

  static const transitionDuration = Duration(milliseconds: 200);
  static const slideTransitionDuration = Duration(milliseconds: 350);
  static const slideReverseTransitionDuration = Duration(milliseconds: 300);

  static Widget softTransition(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }

  static Widget slideUpTransition(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

/// GoRouter page that slides up over the current route without hiding what's underneath.
Page<T> mimioOverlayGoRoutePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    opaque: false,
    child: child,
    transitionDuration: MimioOverlay.slideTransitionDuration,
    reverseTransitionDuration: MimioOverlay.slideReverseTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      return MimioOverlay.slideUpTransition(animation, child);
    },
  );
}

Future<T?> showMimioSoftDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 300,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: MimioOverlay.barrierColor,
    useRootNavigator: useRootNavigator,
    transitionDuration: MimioOverlay.transitionDuration,
    pageBuilder: (dialogCtx, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: builder(dialogCtx),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      return MimioOverlay.softTransition(animation, child);
    },
  );
}

/// Slides a page up over the current route without hiding what's underneath.
Future<T?> pushMimioOverlayRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Duration transitionDuration = MimioOverlay.slideTransitionDuration,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.transparent,
      maintainState: true,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: MimioOverlay.slideReverseTransitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }
        return MimioOverlay.slideUpTransition(animation, child);
      },
    ),
  );
}

Future<T?> showMimioBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: shape != null ? null : Colors.transparent,
    barrierColor: MimioOverlay.barrierColor,
    shape: shape,
  );
}

class MimioSoftCard extends StatelessWidget {
  const MimioSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(24),
      blur: false,
      tintOpacity: 1,
      padding: padding,
      child: child,
    );
  }
}

class MimioSoftDialogActions extends StatelessWidget {
  const MimioSoftDialogActions({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          actions[i],
        ],
      ],
    );
  }
}

class MimioSoftTextButton extends StatelessWidget {
  const MimioSoftTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: destructive
            ? context.palette.error
            : context.palette.textSecondary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
