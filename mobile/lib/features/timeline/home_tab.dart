import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeTab { today, focus, more }

final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.today);
