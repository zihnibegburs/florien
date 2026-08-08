import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/mimio_logo.dart';
import 'package:mimio/features/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authStateProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    if (mounted &&
        ref.read(authStateProvider).hasValue &&
        ref.read(authStateProvider).value != null) {
      context.go('/home');
    }
  }

  Future<void> _loginWithGoogle() async {
    await ref.read(authStateProvider.notifier).loginWithGoogle();
    if (mounted &&
        ref.read(authStateProvider).hasValue &&
        ref.read(authStateProvider).value != null) {
      context.go('/home');
    }
  }

  Future<void> _loginWithApple() async {
    await ref.read(authStateProvider.notifier).loginWithApple();
    if (mounted &&
        ref.read(authStateProvider).hasValue &&
        ref.read(authStateProvider).value != null) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final s = ref.watch(stringsProvider);

    ref.listen(authStateProvider, (_, next) {
      if (next.hasError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: MimioLogo()),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Mimio',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        s.loginTagline,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: s.email,
                        hintText: 'ornek@email.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? s.emailRequired : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: s.password,
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? s.passwordMin6 : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(s.login),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: context.palette.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            s.orContinueWith,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: context.palette.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authState.isLoading
                            ? null
                            : _loginWithGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(s.loginWithGoogle),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authState.isLoading ? null : _loginWithApple,
                        icon: const Icon(Icons.apple, size: 22),
                        label: Text(s.loginWithApple),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(s.noAccountRegister),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
