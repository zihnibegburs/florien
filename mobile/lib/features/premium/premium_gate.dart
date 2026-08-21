import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/features/premium/premium_features.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';

export 'package:florien/features/premium/premium_features.dart';

bool hasActivePremium(WidgetRef ref) =>
    ref.read(premiumMembershipProvider).valueOrNull?.hasActivePremium == true;

Future<bool> requirePremiumAccess(
  BuildContext context,
  WidgetRef ref,
  PremiumFeature feature,
) async {
  if (hasActivePremium(ref)) return true;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => PremiumMembershipScreen(highlightedFeature: feature),
    ),
  );
  return hasActivePremium(ref);
}
