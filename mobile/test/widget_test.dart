import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthResponse?> build() async => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App renders onboarding before login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith(TestAuthNotifier.new)],
        child: const FlorienApp(),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .text('Bazen plan yapmak bile yorucu gelebilir.')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.text('Bazen plan yapmak bile yorucu gelebilir.'),
      findsOneWidget,
    );
    expect(find.text('Başlayalım'), findsOneWidget);
  });
}
