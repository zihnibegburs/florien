import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps todo lists separate for each profile', () async {
    final storage = TodoListStorage();

    await storage.save(const [
      TodoListDefinition(id: 'personal', name: 'Kişisel'),
    ], profileScope: 'user-1:primary');
    await storage.save(const [
      TodoListDefinition(id: 'work', name: 'İş'),
    ], profileScope: 'user-1:profile-work');

    expect(
      (await storage.load(profileScope: 'user-1:primary')).single.name,
      'Kişisel',
    );
    expect(
      (await storage.load(profileScope: 'user-1:profile-work')).single.name,
      'İş',
    );
    expect(await storage.load(profileScope: 'user-2:primary'), isEmpty);
  });
}
