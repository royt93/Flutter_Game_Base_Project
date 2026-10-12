import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_search_bar.dart';

void main() {
  testWidgets('debounces latest text and clear sends empty value', (
    tester,
  ) async {
    final controller = TextEditingController();
    final changed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandySearchBar(controller: controller, onChanged: changed.add),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'fire');
    await tester.pump(const Duration(milliseconds: 250));
    expect(changed, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'fire sword');
    await tester.pump(const Duration(milliseconds: 299));
    expect(changed, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(changed, ['fire sword']);

    await tester.tap(find.byKey(const ValueKey('candySearchClear')));
    expect(controller.text, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(changed, ['fire sword', '']);
    expect(find.byKey(const ValueKey('candySearchClear')), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('filter chip returns updated immutable selected set', (
    tester,
  ) async {
    Set<String> selected = const {};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FilterChipRow<String>(
              filters: const [
                CandyFilter(value: 'rare', label: 'Rare'),
                CandyFilter(value: 'fire', label: 'Fire'),
              ],
              selectedValues: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fire'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(selected, {'fire'});
    expect(find.byKey(const ValueKey(('filter', 'fire'))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative debounce and duplicate filter values reject', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: CandySearchBar(
          controller: controller,
          debounce: const Duration(milliseconds: -1),
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
    expect(
      () => FilterChipRow<String>(
        filters: const [
          CandyFilter(value: 'same', label: 'One'),
          CandyFilter(value: 'same', label: 'Two'),
        ],
        selectedValues: const {},
        onChanged: (_) {},
      ),
      throwsArgumentError,
    );
    controller.dispose();
  });
}
