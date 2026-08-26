import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openFlorienStoreReview() async {
  const appStoreReview =
      'https://apps.apple.com/app/id6799938907?action=write-review';
  const playStoreMarket = 'market://details?id=com.florien.app';
  const playStoreWeb =
      'https://play.google.com/store/apps/details?id=com.florien.app';

  if (defaultTargetPlatform == TargetPlatform.android) {
    if (await _launchExternal(Uri.parse(playStoreMarket))) return true;
    return _launchExternal(Uri.parse(playStoreWeb));
  }
  return _launchExternal(Uri.parse(appStoreReview));
}

Future<bool> _launchExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
