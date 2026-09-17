import 'package:flutter/material.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

const florienTermsOfUseUrl = 'https://www.wirefire.co/florien/terms';
const florienPrivacyPolicyUrl = 'https://www.wirefire.co/florien/privacy';

Future<void> openFlorienLegalUrl(BuildContext context, String url) async {
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
  } catch (_) {}
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n('Sayfa açılamadı.'))));
}
