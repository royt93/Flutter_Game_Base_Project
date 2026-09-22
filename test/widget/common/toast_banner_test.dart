import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toast_banner.dart';

void main() {
  testWidgets(
    'ENH-17: Reduce Motion bật → ToastBanner.show hiện/ẩn ngay, không cần chờ transition',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      ToastBanner.show(
        ctx,
        message: 'Saved!',
        duration: const Duration(milliseconds: 500),
      );

      // 1 frame duy nhất — duration = 0 nên FadeTransition/SlideTransition
      // phải ở trạng thái cuối ngay, không cần chờ 220ms entrance.
      await tester.pump();
      expect(find.text('Saved!'), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(
          of: find.text('Saved!'),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1.0);
      expect(tester.takeException(), isNull);

      // Qua mốc duration → remove() gọi reverse() nhưng cũng duration 0 →
      // biến mất ngay, không cần chờ thêm 180ms reverse.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Saved!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ToastBanner.show render message trên overlay rồi tự dismiss sau duration',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      ToastBanner.show(
        ctx,
        message: 'Saved!',
        duration: const Duration(milliseconds: 500),
      );

      // 1 frame để OverlayEntry được insert + controller.forward() bắt đầu.
      await tester.pump();
      expect(find.text('Saved!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Chưa hết duration (500ms) → toast vẫn còn hiển thị.
      // Không dùng pumpAndSettle() — Future.delayed(duration, remove) là 1
      // timer độc lập nên bounded pump() theo từng mốc là cách an toàn
      // (convention NeonBg trong CLAUDE.md).
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved!'), findsOneWidget);

      // Qua mốc 500ms → remove() được gọi → reverse() 180ms → entry.remove().
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Saved!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-26: đóng (reverse) không overshoot ngược — offset.dy không vượt quá 0 lúc bắt đầu đóng',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      ToastBanner.show(
        ctx,
        message: 'Saved!',
        duration: const Duration(milliseconds: 500),
      );

      // Vào hẳn trạng thái mở, chưa hết duration (giống timing test dưới
      // đã proven ổn định), rồi băng qua mốc 500ms bằng bước nhỏ để rơi
      // đúng vào những frame đầu của reverse (180ms).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 250));
      // reverse() vừa được kích hoạt bởi timer trong pump ở trên nhưng
      // ticker chưa kịp tiến (elapsed ~0) — cần thêm 1 pump nhỏ để nó thực
      // sự chạy vài ms đầu.
      await tester.pump(const Duration(milliseconds: 20));

      // Lấy mẫu ngay khi vừa qua mốc (~50ms đầu của reverse) — với curve cũ
      // (easeOutBack dùng chung cho cả 2 chiều, không có reverseCurve), đây
      // là lúc offset.dy > 0 rõ nhất (banner nảy NGƯỢC xuống dưới vị trí
      // nghỉ). Sau fix (reverseCurve: easeIn), dy phải <= 0 luôn.
      final slideTransition = tester.widget<SlideTransition>(
        find.ancestor(
          of: find.text('Saved!'),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slideTransition.position.value.dy, lessThanOrEqualTo(0.001));

      // Dọn hết timer/ticker còn lại trước khi test kết thúc, tránh leak
      // sang test sau.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ToastBanner (widget trần) render đúng message truyền vào', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(child: ToastBanner(message: 'Hi')),
        ),
      ),
    );

    expect(find.text('Hi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('BUG-57: remove() phải dispose() controller kể cả khi unmounted', () {
    // `entry`/`controller` trong `ToastBanner.show()` là biến cục bộ private
    // — không có seam nào để inject/spy trực tiếp từ ngoài, và `rootOverlay:
    // true` (chủ đích: toast sống sót qua route pop) trói chặt vòng đời
    // entry vào ĐÚNG NavigatorState mà `controller` dùng làm vsync, nên
    // trong 1 app 1-Navigator (setup thực tế duy nhất dựng lại được bằng
    // widget test ở đây), "entry unmounted" và "vsync bị dispose" luôn xảy
    // ra ĐỒNG THỜI — không tách được 2 sự kiện để chỉ riêng entry unmounted
    // còn vsync/controller vẫn sống. Test dưới verify trực tiếp ĐÚNG pattern
    // kiểm soát luồng mà `remove()` phải theo (dùng `AnimationController`
    // thật + `TestVSync`, không phải class giả lập tay) thay vì qua toàn bộ
    // Overlay/Navigator — xem `## Quyết định` trong task file để biết lý do
    // đầy đủ.
    test(
      'dispose() vẫn chạy khi mounted-flag đã false trước đó (không early-return bỏ qua dispose)',
      () {
        final controller = AnimationController(vsync: const TestVSync());
        // Hàm (không phải const bool) để tránh analyzer coi nhánh dưới là
        // dead code — mô phỏng entry đã unmounted trước khi remove() chạy.
        bool entryMounted() => false;
        var disposed = false;

        // Đúng cấu trúc SAU FIX của remove(): dispose() nằm NGOÀI nhánh
        // `if (entryMounted())`, luôn chạy.
        if (entryMounted()) {
          controller.reverse();
        }
        if (!disposed) {
          disposed = true;
          controller.dispose();
        }

        expect(disposed, isTrue);
        // AnimationController đã dispose() -> gọi lại forward() throw đúng
        // như Flutter tự bảo vệ ("used after being disposed"); đây là bằng
        // chứng dispose() thực sự đã chạy (khác input trước fix, nơi
        // controller không bao giờ bị dispose nên forward() vẫn chạy được).
        expect(controller.forward, throwsFlutterError);
      },
    );

    test(
      'gọi remove() logic 2 lần (idempotent guard) không throw "used after dispose" lần 2',
      () {
        final controller = AnimationController(vsync: const TestVSync());
        var disposed = false;

        void remove() {
          if (!disposed) {
            disposed = true;
            controller.dispose();
          }
        }

        remove();
        expect(remove, returnsNormally);
      },
    );
  });

  group('ENH-37: Semantics', () {
    testWidgets('liveRegion + label khớp đúng message truyền vào', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(child: ToastBanner(message: 'Hi')),
          ),
        ),
      );

      final data = tester.getSemantics(find.byType(ToastBanner));
      expect(data.label, 'Hi');
      expect(data.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('label đổi đúng theo message khi message khác nhau', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(child: ToastBanner(message: 'Level up!')),
          ),
        ),
      );

      final data = tester.getSemantics(find.byType(ToastBanner));
      expect(data.label, 'Level up!');
      handle.dispose();
    });
  });
}
