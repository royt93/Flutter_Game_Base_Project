import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/list_tile_row.dart';

void main() {
  testWidgets('render title/subtitle/leading/trailing, không crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonListTile(
            title: 'Sound',
            subtitle: 'Music & SFX',
            leading: const Icon(Icons.volume_up),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Music & SFX'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('không có subtitle/leading/trailing vẫn render bình thường', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: CommonListTile(title: 'Language')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('có onTap: tap gọi callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonListTile(title: 'Row', onTap: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.text('Row'));
    expect(tapped, isTrue);
  });

  testWidgets('không có onTap: tap không throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Material(child: CommonListTile(title: 'Row'))),
    );

    await tester.tap(find.text('Row'));
    expect(tester.takeException(), isNull);
  });
}
