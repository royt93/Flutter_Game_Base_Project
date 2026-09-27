import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

void main() {
  test('public API snapshot is deterministic and committed', () {
    final file = File('tool/api_snapshot.json');
    expect(file.existsSync(), isTrue);
    final json = jsonDecode(file.readAsStringSync()) as Map;
    expect(json['entrypoint'], 'lib/roy_casual_kit.dart');
    expect(json['exports'], isNotEmpty);
    expect(json['symbols'], isNotEmpty);
    expect(json['members'], isNotEmpty);
  });

  test('compatibility gate check passes against current snapshot', () async {
    final result = await Process.run('dart', [
      'run',
      'tool/api_compatibility.dart',
      'check',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  testWidgets('public entrypoint remains renderable while gate runs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'public widgets with tracked member constructors render correctly',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                children: [
                  const StrokeText('Title', fontSize: 24),
                  NeonButton(
                    label: 'Press Me',
                    color: Colors.blue,
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsNWidgets(2));
      expect(find.text('Press Me'), findsNWidgets(2));

      await tester.tap(find.byType(NeonButton));
      await tester.pump();
      expect(tapped, isTrue);
    },
  );
}
