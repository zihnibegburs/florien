import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/routing/startup_routing.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupDestinationProvider);

    ref.listen(startupDestinationProvider, (previous, next) {
      next.whenData((destination) {
        if (!context.mounted) return;
        if (GoRouterState.of(context).matchedLocation == '/startup') {
          context.go(destination);
        }
      });
    });

    return startup.when(
      data: (destination) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (GoRouterState.of(context).matchedLocation == '/startup') {
            context.go(destination);
          }
        });
        return const Scaffold(body: SizedBox.shrink());
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/login');
        });
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
