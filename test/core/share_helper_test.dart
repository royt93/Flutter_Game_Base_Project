import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/share_helper.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// BUG-59: captures the `ShareParams` a `share_helper.dart` function actually
/// passed through to the platform, without touching a real platform channel
/// — `SharePlatform.instance` is a public testing seam (`share_plus` itself
/// documents `SharePlus.custom(...)`/overriding `SharePlatform.instance` for
/// exactly this).
class _FakeSharePlatform extends SharePlatform {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult('', ShareResultStatus.success);
  }
}

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

    testWidgets(
      'không overlay: image được tạo cũng được dispose (không leak)',
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

        await tester.runAsync(() => captureBoardPng(key));

        expect(created, greaterThan(0));
        expect(
          disposed,
          created,
          reason: 'mọi image tạo ra trong 1 lần capture phải được dispose',
        );
      },
    );

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
        expect(
          disposed,
          created,
          reason: 'board gốc VÀ image overlay đều phải được dispose',
        );
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
          MaterialApp(
            home: Container(key: key, color: Colors.red, width: 50, height: 50),
          ),
        );

        final png = await tester.runAsync(() => captureBoardPng(key));

        expect(png, isNull);
      },
    );
  });

  group('BUG-59: ui.Picture dispose (leak Skia native)', () {
    /// Cùng kỹ thuật với group BUG-29 ở trên nhưng theo dõi `ui.Picture`
    /// (native object riêng biệt `recorder.endRecording()` tạo ra, khác
    /// với `ui.Image` mà BUG-29 đã cover) qua 2 hook tĩnh của chính
    /// `dart:ui`.
    int created = 0;
    int disposed = 0;
    void Function(ui.Picture)? prevOnCreate;
    void Function(ui.Picture)? prevOnDispose;

    setUp(() {
      created = 0;
      disposed = 0;
      prevOnCreate = ui.Picture.onCreate;
      prevOnDispose = ui.Picture.onDispose;
      ui.Picture.onCreate = (_) => created++;
      ui.Picture.onDispose = (_) => disposed++;
    });

    tearDown(() {
      ui.Picture.onCreate = prevOnCreate;
      ui.Picture.onDispose = prevOnDispose;
    });

    // Không assert `disposed == created` tuyệt đối: `renderObject.toImage()`
    // (Flutter framework nội bộ, gọi ở MỌI captureBoardPng bất kể có
    // overlayText hay không) cũng phát sinh Picture riêng của framework qua
    // đúng hook toàn-VM này — không phải Picture của `_withTextOverlay` mà
    // BUG-59 sửa, và không do code của package này tạo ra để mà dispose.
    // Test đúng property cần chứng minh: gap `created - disposed` KHÔNG
    // tăng dần theo số lần gọi lặp lại — nếu Picture riêng của
    // `_withTextOverlay` bị leak (không dispose), gap sẽ tăng thêm đúng 1
    // mỗi lần gọi; baseline cố định từ framework thì không tăng theo N.
    testWidgets(
      'gọi captureBoardPng(overlayText: ...) lặp lại N lần: gap '
      'created-disposed KHÔNG tăng dần theo N (không tích luỹ leak Picture '
      'riêng của _withTextOverlay)',
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

        final gaps = <int>[];
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => captureBoardPng(key, overlayText: 'Run $i'),
          );
          gaps.add(created - disposed);
        }

        expect(created, greaterThan(0));
        expect(
          gaps.last,
          gaps.first,
          reason:
              'gap không tăng dần qua $gaps -> Picture riêng của mỗi lần '
              'gọi đều được dispose, không tích luỹ',
        );
      },
    );
  });

  group('BUG-59: sharePositionOrigin (anchor share sheet trên iPad)', () {
    // `SharePlus.instance` là `static final` — nó chỉ đọc `SharePlatform.
    // instance` ĐÚNG 1 LẦN (lần đầu tiên bị truy cập trong cả file test),
    // rồi giữ luôn platform đó vĩnh viễn cho mọi lệnh gọi `share*()` sau
    // này trong CÙNG isolate — set lại `SharePlatform.instance` ở những
    // test SAU không có tác dụng nữa. Vì vậy dùng ĐÚNG 1 instance
    // `_FakeSharePlatform` dùng chung cho cả group, chỉ reset `lastParams`
    // giữa các test thay vì tạo mới + gán lại `SharePlatform.instance` mỗi
    // lần (làm vậy sẽ khiến các test SAU test đầu tiên luôn thấy
    // `lastParams` null vì `SharePlus.instance` đã khoá vào fake CŨ).
    final fakePlatform = _FakeSharePlatform();
    SharePlatform.instance = fakePlatform;

    setUp(() {
      fakePlatform.lastParams = null;
    });

    testWidgets(
      'shareText: có sharePositionContext -> sharePositionOrigin khớp '
      'đúng Rect toàn cục của widget đó',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(key: key, width: 40, height: 20),
            ),
          ),
        );
        final ctx = key.currentContext!;
        final box = ctx.findRenderObject()! as RenderBox;
        final expectedRect = box.localToGlobal(Offset.zero) & box.size;

        await shareText('hello', sharePositionContext: ctx);

        expect(fakePlatform.lastParams, isNotNull);
        expect(fakePlatform.lastParams!.sharePositionOrigin, expectedRect);
      },
    );

    testWidgets(
      'shareText: không truyền sharePositionContext -> sharePositionOrigin '
      'null (giữ nguyên hành vi cũ, không bắt buộc caller đổi)',
      (tester) async {
        await shareText('hello');

        expect(fakePlatform.lastParams, isNotNull);
        expect(fakePlatform.lastParams!.sharePositionOrigin, isNull);
      },
    );

    testWidgets(
      'shareBoardImage: sharePositionContext truyền đúng qua sharePositionOrigin',
      (tester) async {
        final boundaryKey = GlobalKey();
        final anchorKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                RepaintBoundary(
                  key: boundaryKey,
                  child: Container(color: Colors.red, width: 50, height: 50),
                ),
                SizedBox(key: anchorKey, width: 30, height: 30),
              ],
            ),
          ),
        );
        final ctx = anchorKey.currentContext!;
        final box = ctx.findRenderObject()! as RenderBox;
        final expectedRect = box.localToGlobal(Offset.zero) & box.size;

        await tester.runAsync(
          () => shareBoardImage(
            boundaryKey: boundaryKey,
            text: 'x',
            sharePositionContext: ctx,
          ),
        );

        expect(fakePlatform.lastParams, isNotNull);
        expect(fakePlatform.lastParams!.sharePositionOrigin, expectedRect);
      },
    );
  });
}
