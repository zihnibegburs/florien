import 'dart:async';

import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled under assets/fonts; tests must never fetch them over HTTP.
  GoogleFonts.config.allowRuntimeFetching = false;
  binding.platformDispatcher
    ..localeTestValue = const Locale('tr')
    ..localesTestValue = const [Locale('tr')];
  ActiveLanguage.code = 'tr';
  await testMain();
}
