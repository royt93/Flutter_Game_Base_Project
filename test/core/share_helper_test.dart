import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/share_helper.dart';

void main() {
  testWidgets('captureBoardPng trả về PNG bytes khi context đã build', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(color: Colors.red, width: 50, height: 50),
        ),
      ),
    );

    final png = await tester.runAsync(() => captureBoardPng(key));

    expect(png, isNotNull);
    expect(png!.length, greaterThan(8));
    // PNG magic bytes.
    expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  testWidgets('captureBoardPng trả về null khi context chưa build', (
    tester,
  ) async {
    final key = GlobalKey();
    final png = await captureBoardPng(key);
    expect(png, isNull);
  });

  testWidgets('captureBoardPng với overlayText vẫn trả về PNG hợp lệ', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(color: Colors.red, width: 50, height: 50),
        ),
      ),
    );

    final png = await tester.runAsync(
      () => captureBoardPng(key, overlayText: 'Level 1 — Score 760'),
    );

    expect(png, isNotNull);
    expect(png!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
