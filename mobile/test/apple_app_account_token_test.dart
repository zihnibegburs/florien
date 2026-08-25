import 'package:florien/core/services/apple_app_account_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appAccountTokenForUid matches RFC 4122 UUID v5', () {
    expect(
      appAccountTokenForUid('testUid123'),
      '7d869285-b212-5224-a857-f123b8e9e1b1',
    );
    expect(
      appAccountTokenForUid('abc'),
      '7459bb99-201e-5554-b228-042d1c52c1c4',
    );
  });
}
