import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/routing/startup_routing.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_logo.dart';
import 'package:florien/features/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  Future<void> _loginWithGoogle() async {
    await ref.read(authStateProvider.notifier).loginWithGoogle();
    if (mounted && ref.read(authStateProvider).valueOrNull != null) {
      await navigateAfterAuth(context, ref);
    }
  }

  Future<void> _loginWithApple() async {
    await ref.read(authStateProvider.notifier).loginWithApple();
    if (mounted && ref.read(authStateProvider).valueOrNull != null) {
      await navigateAfterAuth(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    ref.listen(authStateProvider, (_, next) {
      if (next.hasError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    });

    return Theme(
      data: FlorienTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF16141A),
          body: Stack(
            children: [
              const _AuthBackdrop(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          const FlorienLogo(size: 112),
                          const SizedBox(height: 28),
                          Text(
                            'Florien',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Hepsi bir arada planlama\nve üretkenlik',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontSize: 31,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gününü kendi ritmine göre düzenle.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 44),
                          _AuthActionButton(
                            label: 'Apple ile devam et',
                            icon: Icons.apple,
                            light: true,
                            loading: authState.isLoading,
                            onPressed: _loginWithApple,
                          ),
                          const SizedBox(height: 12),
                          _AuthActionButton(
                            label: 'Google ile devam et',
                            icon: Icons.g_mobiledata_rounded,
                            loading: authState.isLoading,
                            onPressed: _loginWithGoogle,
                          ),
                          const SizedBox(height: 12),
                          _AuthActionButton(
                            label: 'E-posta ile devam et',
                            icon: Icons.mail_outline_rounded,
                            outline: true,
                            loading: authState.isLoading,
                            onPressed: () => context.go('/register'),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Zaten bir hesabın var mı?',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/email-login'),
                            child: const Text('Giriş Yap'),
                          ),
                        ],
                      ),
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
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          top: -180,
          right: -100,
          child: _Glow(color: FlorienColors.aiAccent.withValues(alpha: 0.3)),
        ),
        Positioned(
          top: 280,
          left: -160,
          child: _Glow(color: FlorienColors.paleBlue.withValues(alpha: 0.22)),
        ),
        Positioned(
          bottom: -200,
          right: -120,
          child: _Glow(color: FlorienColors.softLime.withValues(alpha: 0.18)),
        ),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 380,
    height: 380,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.loading,
    this.light = false,
    this.outline = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;
  final bool light;
  final bool outline;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton.icon(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: light
            ? FlorienColors.darkTextPrimary
            : outline
            ? Colors.transparent
            : context.palette.surface,
        foregroundColor: light
            ? FlorienColors.onPrimary
            : context.palette.textPrimary,
        side: BorderSide(
          color: outline
              ? context.palette.textSecondary
              : context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      icon: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: light
                    ? FlorienColors.onPrimary
                    : context.palette.textPrimary,
              ),
            )
          : Icon(icon, size: icon == Icons.g_mobiledata_rounded ? 28 : 22),
      label: Text(label),
    ),
  );
}
