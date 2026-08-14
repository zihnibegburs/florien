import 'package:flutter_test/flutter_test.dart';
import 'package:florien/features/task_icon/data/task_icon_lexicon.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/services/task_icon_classifier.dart';

void main() {
  test('matches conjugated Turkish running titles', () {
    expect(TaskIconLexicon.match('koşacağım'), TaskCategory.running);
    expect(TaskIconLexicon.match('Koşacağım'), TaskCategory.running);
    expect(TaskIconLexicon.match('koşuyorum'), TaskCategory.running);
    expect(TaskIconLexicon.match('sabah koşacağım'), TaskCategory.running);
    expect(TaskIconLexicon.match('koşu'), TaskCategory.running);
  });

  test('matches short Turkish and English car repair titles', () {
    expect(TaskIconLexicon.match('araba tamiri'), TaskCategory.carRepair);
    expect(TaskIconLexicon.match('Araba Tamiri'), TaskCategory.carRepair);
    expect(TaskIconLexicon.match('car repair'), TaskCategory.carRepair);
    expect(TaskIconLexicon.match('Car Repair'), TaskCategory.carRepair);
    expect(TaskIconLexicon.match('repair the car'), TaskCategory.carRepair);
  });

  test('does not treat home repair as car repair', () {
    expect(TaskIconLexicon.match('ev tamiri'), TaskCategory.homeRepair);
  });

  test('classifies everyday multilingual titles', () {
    expect(TaskIconLexicon.match('Buy milk'), TaskCategory.groceries);
    expect(TaskIconLexicon.match('Call mom'), TaskCategory.phoneCall);
    expect(TaskIconLexicon.match('Morning run'), TaskCategory.running);
    expect(TaskIconLexicon.match('Pay electricity bill'), TaskCategory.bills);
    expect(TaskIconLexicon.match('Flight to Bangkok'), TaskCategory.flight);
    expect(TaskIconLexicon.match('laufen'), TaskCategory.running);
    expect(TaskIconLexicon.match('correr'), TaskCategory.running);
    expect(TaskIconLexicon.match('courir'), TaskCategory.running);
  });

  test('classifier uses the lexicon without needing the ONNX model', () async {
    final classifier = TaskIconClassifier();

    final running = await classifier.classify('koşacağım');
    final turkish = await classifier.classify('araba tamiri');
    final english = await classifier.classify('car repair');
    final milk = await classifier.classify('Buy milk');

    expect(running.category, TaskCategory.running);
    expect(turkish.category, TaskCategory.carRepair);
    expect(english.category, TaskCategory.carRepair);
    expect(milk.category, TaskCategory.groceries);
  });
}
