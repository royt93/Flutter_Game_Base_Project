import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/hold_to_confirm_button.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(child: Center(child: child)),
);

void main() {
  const duration = Duration(milliseconds: 600);

  // HoldToConfirmButton's default haptics go through HapticChoreographer ->
  // fireHaptic(), which reads StorageService.to (an ambient Get singleton)
  // to check the hapticsEnabled/hapticSoftMode flags — register an
  // in-memory fallback so these gesture tests don't need to fake haptics
  // themselves just to avoid a "StorageService not found" crash.
  setUp(() => Get.put<StorageService>(StorageService(null)));
  tearDown(Get.reset);

  testWidgets('giữ đủ duration gọi onConfirm đúng 1 lần', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      _wrap(
        HoldToConfirmButton(
          label: 'Delete',
          duration: duration,
          onConfirm: () => count++,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    // Ticker chỉ ghi nhận mốc thời gian bắt đầu ở LẦN TICK ĐẦU TIÊN — phải
    // pump() rỗng ngay sau khi bắt đầu animation trước khi nhảy cả khối
    // thời gian lớn, không thì AnimationController không tiến (value đứng
    // yên ở 0 dù pump bao lâu).
    await tester.pump();
    await tester.pump(duration + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(count, 1);
  });

  testWidgets('thả trước khi đủ duration: không gọi onConfirm, progress về 0', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _wrap(
        HoldToConfirmButton(
          label: 'Delete',
          duration: duration,
          onConfirm: () => count++,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(count, 0);
  });

  testWidgets(
    'kéo ra ngoài bounds trước khi đủ duration: huỷ, không gọi onConfirm',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirmButton(
            label: 'Delete',
            duration: duration,
            onConfirm: () => count++,
          ),
        ),
      );

      final center = tester.getCenter(find.byType(HoldToConfirmButton));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, 1000));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();

      expect(count, 0);
    },
  );

  testWidgets('rage tap (down-up nhanh liên tục) không bao giờ gọi onConfirm', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _wrap(
        HoldToConfirmButton(
          label: 'Delete',
          duration: duration,
          onConfirm: () => count++,
        ),
      ),
    );

    final center = tester.getCenter(find.byType(HoldToConfirmButton));
    for (var i = 0; i < 5; i++) {
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 30));
    }

    expect(count, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pointer thứ 2 trong lúc đang giữ bị bỏ qua, hold gốc vẫn hoạt động đúng',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirmButton(
            label: 'Delete',
            duration: duration,
            onConfirm: () => count++,
          ),
        ),
      );

      final center = tester.getCenter(find.byType(HoldToConfirmButton));
      final first = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final second = await tester.startGesture(center, pointer: 2);
      await tester.pump(const Duration(milliseconds: 100));
      await second.up();
      await tester.pump(duration);
      await first.up();
      await tester.pump();

      expect(count, 1);
    },
  );

  testWidgets(
    '2 lần giữ liên tiếp (reentrant) gọi đúng 2 lần, không rò rỉ state',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _wrap(
          HoldToConfirmButton(
            label: 'Delete',
            duration: duration,
            onConfirm: () => count++,
          ),
        ),
      );

      final center = tester.getCenter(find.byType(HoldToConfirmButton));
      for (var i = 0; i < 2; i++) {
        final gesture = await tester.startGesture(center);
        await tester.pump();
        await tester.pump(duration + const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 400)); // hồi về idle
      }

      expect(count, 2);
    },
  );

  testWidgets('disabled: giữ đủ duration cũng không gọi onConfirm', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _wrap(
        HoldToConfirmButton(
          label: 'Delete',
          duration: duration,
          enabled: false,
          onConfirm: () => count++,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    await tester.pump();
    await tester.pump(duration + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(count, 0);
    expect(
      tester
          .getSemantics(find.byType(HoldToConfirmButton))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
  });

  testWidgets(
    'screen reader path: SemanticsAction.tap gọi onConfirm ngay, không cần giữ',
    (tester) async {
      var count = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          HoldToConfirmButton(
            label: 'Delete',
            duration: duration,
            onConfirm: () => count++,
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(HoldToConfirmButton));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        semantics.id,
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(count, 1);
      handle.dispose();
    },
  );

  testWidgets(
    'reduced motion: duration KHÔNG bị rút ngắn — vẫn cần giữ đủ thời gian',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Material(
              child: Center(
                child: HoldToConfirmButton(
                  label: 'Delete',
                  duration: duration,
                  onConfirm: () => count++,
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToConfirmButton)),
      );
      await tester.pump();
      await tester.pump(duration - const Duration(milliseconds: 100));
      expect(count, 0); // chưa đủ, kể cả reduced motion

      await tester.pump(const Duration(milliseconds: 150));
      await gesture.up();
      await tester.pump();

      expect(count, 1);
    },
  );

  testWidgets('unmount giữa chừng lúc đang giữ không throw', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      _wrap(
        HoldToConfirmButton(
          label: 'Delete',
          duration: duration,
          onConfirm: () => count++,
        ),
      ),
    );

    await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(_wrap(const SizedBox()));
    await tester.pump(duration);

    expect(tester.takeException(), isNull);
    expect(count, 0);
  });
}
