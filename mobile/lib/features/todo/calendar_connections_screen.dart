import 'package:flutter/material.dart';
import 'package:flutter_icon_park/flutter_icon_park.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/services/calendar_connection_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/premium/premium_membership.dart';

class CalendarConnectionsScreen extends ConsumerStatefulWidget {
  const CalendarConnectionsScreen({super.key});

  @override
  ConsumerState<CalendarConnectionsScreen> createState() =>
      _CalendarConnectionsScreenState();
}

class _CalendarConnectionsScreenState
    extends ConsumerState<CalendarConnectionsScreen> {
  CalendarProvider? _connecting;

  Future<void> _connect(CalendarProvider provider) async {
    if (_connecting != null) return;
    if (!await requirePremiumAccess(
      context,
      ref,
      PremiumFeature.calendarImport,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _connecting = provider);
    try {
      final connection = await ref
          .read(calendarConnectionServiceProvider)
          .connect(provider);
      if (!mounted || connection == null) return;
      ref.invalidate(calendarConnectionsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${connection.name} bağlandı.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  Future<void> _disconnect(CalendarProvider provider) async {
    await ref.read(calendarConnectionServiceProvider).disconnect(provider);
    ref.invalidate(calendarConnectionsProvider);
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst(
      'Unsupported operation: ',
      '',
    );
    return message.replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(calendarConnectionsProvider);
    final connectedProviders =
        connections.valueOrNull
            ?.map((connection) => connection.provider)
            .toSet() ??
        const <CalendarProvider>{};
    final isPremium = ref.watch(
      premiumMembershipProvider.select(
        (membership) => membership.valueOrNull?.hasActivePremium == true,
      ),
    );

    return Scaffold(
      key: const ValueKey('calendar-connections-screen'),
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FlorienSpacing.screen,
            FlorienSpacing.md,
            FlorienSpacing.screen,
            FlorienSpacing.huge,
          ),
          children: [
            Row(
              children: [
                Material(
                  color: context.palette.surface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: context.palette.border,
                      width: FlorienBorders.thin,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox.square(
                      dimension: 40,
                      child: Icon(Icons.chevron_left_rounded, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Bağlı Takvimler',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Takvimini bağla',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Apple ve Google Takvimini aynı anda bağlayabilirsin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            _CalendarConnectButton(
              provider: CalendarProvider.apple,
              isConnected: connectedProviders.contains(CalendarProvider.apple),
              isLoading: _connecting == CalendarProvider.apple,
              isPremium: isPremium,
              onTap: () => _connect(CalendarProvider.apple),
            ),
            const SizedBox(height: 14),
            _CalendarConnectButton(
              provider: CalendarProvider.google,
              isConnected: connectedProviders.contains(CalendarProvider.google),
              isLoading: _connecting == CalendarProvider.google,
              isPremium: isPremium,
              onTap: () => _connect(CalendarProvider.google),
            ),
            const SizedBox(height: FlorienSpacing.xxxl),
            Text(
              'Bağlı takvimler',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: FlorienSpacing.md),
            connections.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) =>
                  _CalendarEmptyState(message: 'Bağlı takvimler yüklenemedi.'),
              data: (items) => items.isEmpty
                  ? const _CalendarEmptyState(
                      message: 'Bağlı takvimlerin burada görünecek.',
                    )
                  : Column(
                      children: [
                        for (final connection in items) ...[
                          _ConnectedCalendarCard(
                            connection: connection,
                            onDisconnect: () =>
                                _disconnect(connection.provider),
                          ),
                          if (connection != items.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarConnectButton extends StatelessWidget {
  const _CalendarConnectButton({
    required this.provider,
    required this.isConnected,
    required this.isLoading,
    required this.isPremium,
    required this.onTap,
  });

  final CalendarProvider provider;
  final bool isConnected;
  final bool isLoading;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = switch (provider) {
      CalendarProvider.apple => 'Apple Takvimini Bağla',
      CalendarProvider.google => 'Google Takvimini Bağla',
    };

    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(FlorienRadius.pill),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.pill),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            border: Border.all(
              color: context.palette.border,
              width: FlorienBorders.thin,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProviderIcon(provider: provider, size: 34),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  isConnected ? '$text · Bağlı' : text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isLoading) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ] else if (!isPremium) ...[
                const SizedBox(width: 12),
                const Icon(Icons.lock_outline_rounded, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectedCalendarCard extends StatelessWidget {
  const _ConnectedCalendarCard({
    required this.connection,
    required this.onDisconnect,
  });

  final CalendarConnection connection;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          _ProviderIcon(provider: connection.provider, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connection.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bağlantıyı kaldır',
            onPressed: onDisconnect,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(FlorienRadius.lg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: context.palette.textSecondary,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({required this.provider, required this.size});

  final CalendarProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) => switch (provider) {
    CalendarProvider.apple => IconPark.apple.filled(
      fill: context.palette.textPrimary,
      size: size,
    ),
    CalendarProvider.google => IconPark.google.multiColor(
      outStrokeColor: const Color(0xFF4285F4),
      outFillColor: const Color(0xFFEA4335),
      innerStrokeColor: const Color(0xFFFBBC05),
      innerFillColor: const Color(0xFF34A853),
      size: size,
    ),
  };
}
