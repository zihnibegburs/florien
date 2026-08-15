import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/florien_logo.dart';
import 'package:florien/features/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _updatesEnabled = true;
  String? _primaryNeed;
  String? _neuroProfile;
  bool _finishing = false;

  Future<void> _finish() async {
    if (_primaryNeed == null || _neuroProfile == null) return;
    setState(() => _finishing = true);
    await ref
        .read(onboardingPreferencesProvider.notifier)
        .complete(
          productUpdatesEnabled: _updatesEnabled,
          primaryNeed: _primaryNeed!,
          neuroProfile: _neuroProfile!,
        );
    if (mounted) context.go('/todo');
  }

  void _next() => setState(() => _step++);

  void _back() => setState(() => _step--);

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingPreferencesProvider);
    return Theme(
      data: FlorienTheme.dark,
      child: Builder(
        builder: (context) => onboarding.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => _OnboardingFrame(
            step: _step,
            onBack: _step == 0 ? null : _back,
            child: _content(context),
          ),
          data: (preferences) {
            if (preferences.completed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go('/todo');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return _OnboardingFrame(
              step: _step,
              onBack: _step == 0 ? null : _back,
              child: _content(context),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: switch (_step) {
      0 => _UpdatesStep(
        key: const ValueKey('onboarding-updates'),
        enabled: _updatesEnabled,
        onChanged: (value) => setState(() => _updatesEnabled = value),
        onNext: _next,
      ),
      1 => _ChoiceStep(
        key: const ValueKey('onboarding-primary-need'),
        title: 'Şu anda en büyük ihtiyacın ne?',
        description:
            'Sana iyi gelen başlangıcı hazırlamak için günlük hayatında en çok neye destek istediğini bilmek isteriz.',
        choices: const [
          'Günümü ve saatimi düzenle',
          'Görevlerimi hatırla',
          'Yapılacaklarımı düzenle',
          'Rutinler oluştur ve sürdür',
          'Odak çalışmasında destek ol',
          'Başka bir şey',
        ],
        selected: _primaryNeed,
        onSelected: (value) => setState(() => _primaryNeed = value),
        onNext: _next,
      ),
      2 => _ChoiceStep(
        key: const ValueKey('onboarding-neuro-profile'),
        title: 'Nörofarklı mısın?',
        description:
            'Florien, odaklanmana ve gününü kolaylıkla planlamana yardımcı olur. Bunlardan hangisi sana daha yakın?',
        choices: const [
          'Ben nöroçeşitliyim',
          'Sanırım nörolojik olarak farklıyım',
          'Ben nörofarklı değilim',
          'Bilmiyorum',
        ],
        selected: _neuroProfile,
        onSelected: (value) => setState(() => _neuroProfile = value),
        onNext: _next,
      ),
      3 => _PaywallStep(
        key: const ValueKey('onboarding-paywall'),
        onContinueFree: _next,
        onSubscribe: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pro aboneliği yakında bu ekrandan açılacak.'),
            ),
          );
        },
      ),
      _ => _WelcomeStep(
        key: const ValueKey('onboarding-welcome'),
        primaryNeed: _primaryNeed ?? '',
        finishing: _finishing,
        onFinish: _finish,
      ),
    },
  );
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({
    required this.step,
    required this.child,
    this.onBack,
  });

  final int step;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final showProgress = step > 0 && step < 4;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        if (onBack != null)
                          IconButton(
                            tooltip: 'Geri',
                            onPressed: onBack,
                            style: IconButton.styleFrom(
                              backgroundColor: context.palette.surface,
                              foregroundColor: context.palette.textPrimary,
                              side: BorderSide(
                                color: context.palette.border,
                                width: FlorienBorders.thin,
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          )
                        else
                          const SizedBox(width: 48),
                        const Spacer(),
                        if (showProgress)
                          Container(
                            width: 128,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.palette.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                FlorienRadius.pill,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: step / 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: FlorienColors.aiGradient,
                                  borderRadius: BorderRadius.circular(
                                    FlorienRadius.pill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdatesStep extends StatelessWidget {
  const _UpdatesStep({
    super.key,
    required this.enabled,
    required this.onChanged,
    required this.onNext,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: context.palette.aiSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: FlorienColors.aiAccent,
                width: FlorienBorders.thin,
              ),
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              size: 56,
              color: FlorienColors.paleBlue,
            ),
          ),
        ),
        Text(
          'Florien güncellemelerini almak ister misin?',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 14),
        Text(
          'Yeni özellikler, yararlı ipuçları ve sana uygun tekliflerden haberdar ol.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: 28),
        _SelectionCard(
          selected: !enabled,
          title: 'Hayır, istemiyorum',
          description: 'Sadece uygulama içi gerekli bildirimleri alacağım.',
          accent: FlorienColors.paleBlue,
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: 12),
        _SelectionCard(
          selected: enabled,
          title: 'Evet, istiyorum',
          description:
              'Güncellemelerden, özel tekliflerden ve gelişmelerden haberdar olacağım.',
          accent: FlorienColors.softLime,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('onboarding-updates-next'),
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Devam'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Tercihini daha sonra Ayarlar’dan değiştirebilirsin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    super.key,
    required this.title,
    required this.description,
    required this.choices,
    required this.selected,
    required this.onSelected,
    required this.onNext,
  });

  final String title;
  final String description;
  final List<String> choices;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
      ),
      const SizedBox(height: 30),
      Expanded(
        child: ListView.separated(
          itemCount: choices.length,
          itemBuilder: (context, index) {
            final choice = choices[index];
            return _ChoiceButton(
              label: choice,
              selected: selected == choice,
              onTap: () => onSelected(choice),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 12),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('onboarding-choice-next'),
          onPressed: selected == null ? null : onNext,
          child: const Text('Devam'),
        ),
      ),
    ],
  );
}

class _PaywallStep extends StatelessWidget {
  const _PaywallStep({
    super.key,
    required this.onContinueFree,
    required this.onSubscribe,
  });

  final VoidCallback onContinueFree;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (_) => const Icon(
                Icons.star_rounded,
                color: FlorienColors.softLime,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Profesyonel gibi planla',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Daha fazla destek istersen Florien Pro her zaman yanında.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(FlorienRadius.lg),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Column(
            children: const [
              _ProFeature('Yapay zekâ ortak planlayıcı'),
              _ProFeature('Akıllı alt görev önerileri'),
              _ProFeature('Odak zamanlayıcısı ve ödüller'),
              _ProFeature('Takvim entegrasyonları'),
              _ProFeature('Canlı etkinlikler ve widget’lar'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSubscribe,
            child: const Text('Pro’yu keşfet'),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            key: const ValueKey('onboarding-continue-free'),
            onPressed: onContinueFree,
            child: const Text('Şimdilik ücretsiz devam et'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Abonelik zorunlu değildir. İstediğin zaman Ayarlar’dan Pro’ya geçebilirsin.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    super.key,
    required this.primaryNeed,
    required this.finishing,
    required this.onFinish,
  });

  final String primaryNeed;
  final bool finishing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: FlorienColors.aiGradient,
          border: Border.all(
            color: context.palette.textPrimary,
            width: FlorienBorders.thin,
          ),
        ),
        child: const FlorienLogo(size: 96),
      ),
      const SizedBox(height: 34),
      Text(
        'Harika, hazırız!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'İlk adımlarını $primaryNeed ihtiyacına göre kolaylaştıracağız.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
      ),
      const SizedBox(height: 40),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.palette.aiSurface,
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: FlorienColors.softLime),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Florien senin hızına göre şekillenir. Küçük adımlarla başlayalım.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 36),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('onboarding-finish'),
          onPressed: finishing ? null : onFinish,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(finishing ? 'Hazırlanıyor…' : 'Hadi başlayalım'),
        ),
      ),
    ],
  );
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: Border.all(
            color: selected ? accent : context.palette.border,
            width: selected ? FlorienBorders.medium : FlorienBorders.thin,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? accent : context.palette.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(60),
      backgroundColor: selected
          ? context.palette.aiSurface
          : Colors.transparent,
      side: BorderSide(
        color: selected ? FlorienColors.aiAccent : context.palette.border,
        width: selected ? FlorienBorders.medium : FlorienBorders.thin,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlorienRadius.pill),
      ),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label, textAlign: TextAlign.center)),
        if (selected)
          const Icon(
            Icons.check_rounded,
            size: 18,
            color: FlorienColors.softLime,
          ),
      ],
    ),
  );
}

class _ProFeature extends StatelessWidget {
  const _ProFeature(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: FlorienColors.aiAccent,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
