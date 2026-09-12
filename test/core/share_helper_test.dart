import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/share_helper.dart';

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

  group('BUG-29', () {
    /// Đếm mọi `ui.Image` được tạo/dispose trong toàn VM qua 2 static hook
    /// của chính `dart:ui` (`Image.onCreate`/`onDispose`) — không cần thêm
    /// bất kỳ counter `@visibleForTesting` nào vào `share_helper.dart`.
    int created = 0;
    int disposed = 0;
    void Function(ui.Image)? prevOnCreate;
    void Function(ui.Image)? prevOnDispose;

    setUp(() {
      created = 0;
      disposed = 0;
      prevOnCreate = ui.Image.onCreate;
      prevOnDispose = ui.Image.onDispose;
      ui.Image.onCreate = (_) => created++;
      ui.Image.onDispose = (_) => disposed++;
    });

    tearDown(() {
      ui.Image.onCreate = prevOnCreate;
      ui.Image.onDispose = prevOnDispose;
    });

    testWidgets('không overlay: image được tạo cũng được dispose (không leak)', (
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

      await tester.runAsync(() => captureBoardPng(key));

      expect(created, greaterThan(0));
      expect(disposed, created, reason: 'mọi image tạo ra trong 1 lần capture phải được dispose');
    });

    testWidgets(
      'có overlayText (tạo 2 image: board gốc + composited): cả 2 đều '
      'được dispose (không leak)',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: Container(color: Colors.red, width: 50, height: 50),
            ),
          ),
        );

        await tester.runAsync(
          () => captureBoardPng(key, overlayText: 'Level 1'),
        );

        expect(created, greaterThanOrEqualTo(2));
        expect(disposed, created, reason: 'board gốc VÀ image overlay đều phải được dispose');
      },
    );

    testWidgets(
      'gọi lặp lại nhiều lần liên tiếp: tổng dispose luôn khớp tổng tạo ra '
      '(không tích luỹ leak qua nhiều lần share)',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: Container(color: Colors.red, width: 50, height: 50),
            ),
          ),
        );

        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => captureBoardPng(key, overlayText: 'Run $i'),
          );
        }

        expect(disposed, created);
      },
    );

    testWidgets(
      'key gắn vào widget KHÔNG phải RenderRepaintBoundary → trả về null '
      '(kết quả "không capture" đã tài liệu hoá) thay vì crash type error',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(home: Container(key: key, color: Colors.red, width: 50, height: 50)),
        );

        final png = await tester.runAsync(() => captureBoardPng(key));

        expect(png, isNull);
      },
    );
  });
}
