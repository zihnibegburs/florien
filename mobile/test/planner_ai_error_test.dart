import 'package:florien/core/services/planner_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI protection reasons become user-friendly Turkish messages', () {
    expect(
      aiFunctionsErrorMessage(
        code: 'permission-denied',
        details: const {'reason': 'PREMIUM_REQUIRED'},
      ),
      contains('Premium'),
    );
    expect(
      aiFunctionsErrorMessage(
        code: 'resource-exhausted',
        details: const {
          'reason': 'AI_RATE_LIMIT_MINUTE',
          'retryAt': '2026-08-20T12:34:00.000Z',
        },
      ),
      allOf(contains('Bir dakika'), contains('tekrar')),
    );
    expect(
      aiFunctionsErrorMessage(
        code: 'resource-exhausted',
        details: const {'reason': 'AI_RATE_LIMIT_HOURLY'},
      ),
      contains('Saatlik'),
    );
    expect(
      aiFunctionsErrorMessage(
        code: 'resource-exhausted',
        details: const {'reason': 'AI_DAILY_LIMIT_REACHED'},
      ),
      contains('Günlük'),
    );
    expect(
      aiFunctionsErrorMessage(
        code: 'resource-exhausted',
        details: const {'reason': 'AI_FREE_CHAT_MONTHLY_LIMIT_REACHED'},
      ),
      contains('ücretsiz AI mesaj'),
    );
    expect(
      aiFunctionsErrorMessage(
        code: 'resource-exhausted',
        details: const {'reason': 'AI_MONTHLY_LIMIT_REACHED'},
      ),
      contains('Aylık'),
    );
    expect(
      aiFunctionsErrorMessage(
        code: 'invalid-argument',
        details: const {'reason': 'AI_INPUT_TOO_LONG'},
      ),
      contains('2000 karakter'),
    );
  });

  test('generic breakdown failures keep breakdown-specific copy', () {
    expect(
      aiFunctionsErrorMessage(code: 'internal', breakdown: true),
      contains('alt görevleri'),
    );
  });
}
