import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/async_common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

// disableAnimations tắt AnimatedSwitcher crossfade (200ms) — các test dưới
// không quan tâm animation, chỉ quan tâm trạng thái/timer; không tắt sẽ có
// lúc bắt được cả CommonButton cũ lẫn mới trong lúc crossfade (flaky "Too
// many elements"). Riêng test "reduced motion" và test RTL/text-scale tự
// dựng widget tree, không dùng helper này.
Widget _wrap(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Material(child: child),
  ),
);

void main() {
  testWidgets('tap gọi onPressed một lần, nút chuyển sang loading', (
    tester,
  ) async {
    var callCount = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        AsyncCommonButton(
          label: 'Save',
          onPressed: () {
            callCount++;
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    expect(callCount, 1);
    final button = tester.widget<CommonButton>(find.byType(CommonButton));
    expect(button.loading, true);

    completer.complete();
    await tester.pump();
  });

  testWidgets('rapid tap trong lúc loading chỉ chạy một Future', (
    tester,
  ) async {
    var callCount = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        AsyncCommonButton(
          label: 'Save',
          onPressed: () {
            callCount++;
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    await tester.tap(find.byType(AsyncCommonButton));
    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    expect(callCount, 1);

    completer.complete();
    await tester.pump();
  });

  testWidgets('thành công: về idle sau successDuration, cho phép tap lại', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      _wrap(
        AsyncCommonButton(
          label: 'Save',
          successDuration: const Duration(milliseconds: 100),
          onPressed: () async {
            callCount++;
          },
        ),
      ),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    await tester.pump();

    var button = tester.widget<CommonButton>(find.byType(CommonButton));
    expect(button.loading, false);
    expect(button.onTap, isNull); // vẫn khoá trong lúc hiện success

    await tester.pump(const Duration(milliseconds: 150));

    button = tester.widget<CommonButton>(find.byType(CommonButton));
    expect(button.onTap, isNotNull); // đã về idle, tap lại được

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    expect(callCount, 2);

    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('lỗi: onPressed throw -> về idle sau errorDuration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AsyncCommonButton(
          label: 'Save',
          errorDuration: const Duration(milliseconds: 100),
          onPressed: () async => throw Exception('boom'),
        ),
      ),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    await tester.pump();

    var button = tester.widget<CommonButton>(find.byType(CommonButton));
    expect(button.onTap, isNull);

    await tester.pump(const Duration(milliseconds: 150));

    button = tester.widget<CommonButton>(find.byType(CommonButton));
    expect(button.onTap, isNotNull);
  });

  testWidgets('timeout: onPressed không xong kịp -> coi như lỗi', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        AsyncCommonButton(
          label: 'Save',
          timeout: const Duration(milliseconds: 50),
          errorDuration: const Duration(milliseconds: 100),
          onPressed: () => completer.future,
        ),
      ),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final button = tester.widget<CommonButton>(find.byType(CommonButton));
    expect(button.onTap, isNull); // đang ở trạng thái error, không phải idle

    await tester.pump(const Duration(milliseconds: 150));
    completer.complete();
  });

  testWidgets('unmount trong lúc chờ future không gọi setState/lỗi', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(AsyncCommonButton(label: 'Save', onPressed: () => completer.future)),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox()));
    completer.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('width không đổi giữa các trạng thái idle/loading/success', (
    tester,
  ) async {
    void Function() complete = () {};
    await tester.pumpWidget(
      _wrap(
        AsyncCommonButton(
          label: 'Save',
          width: 200,
          successDuration: const Duration(milliseconds: 100),
          onPressed: () {
            final c = Completer<void>();
            complete = () => c.complete();
            return c.future;
          },
        ),
      ),
    );

    final idleWidth = tester.getSize(find.byType(AsyncCommonButton)).width;

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();
    final loadingWidth = tester.getSize(find.byType(AsyncCommonButton)).width;

    complete();
    await tester.pump();
    final successWidth = tester.getSize(find.byType(AsyncCommonButton)).width;

    expect(loadingWidth, idleWidth);
    expect(successWidth, idleWidth);

    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('reduced motion: AnimatedSwitcher duration = 0', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Material(
            child: AsyncCommonButton(label: 'Save', onPressed: () async {}),
          ),
        ),
      ),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, Duration.zero);
  });

  testWidgets('RTL + text scale lớn không throw, không tràn layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Material(
              child: Center(
                child: AsyncCommonButton(label: 'Save', onPressed: () async {}),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
