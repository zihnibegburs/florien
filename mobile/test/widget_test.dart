import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/main.dart';

class TestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthResponse?> build() async => null;
}

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(TestAuthNotifier.new),
        ],
        child: const FlorienApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
