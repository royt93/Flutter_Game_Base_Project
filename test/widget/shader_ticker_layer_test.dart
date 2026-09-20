import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/performance_tier_service.dart';
import 'package:roy_casual_kit/presentation/widgets/aurora_bg_layer.dart';

/// Covers `ShaderTickerLayerState`'s reaction to `PerformanceTierService`
/// (tested through its concrete subclass `AuroraBgLayer` — the base class
/// itself is abstract). Reduce Motion coverage for `AuroraBgLayer`/
/// `NeonAuraLayer` already lives in `aurora_bg_layer_test.dart`/
/// `neon_aura_layer_test.dart`; this file is additive, not a replacement.
void main() {
  tearDown(Get.reset);

  testWidgets(
    'không đăng ký PerformanceTierService → ticker vẫn chạy như trước',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
      );
      await tester.pump();

      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tier=low ngay lúc mount → không chạy ticker', (tester) async {
    Get.put(PerformanceTierService()..tier.value = PerformanceTier.low);

    await tester.pumpWidget(
      MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
    );
    await tester.pump();

    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tier chuyển sang low sau khi mount → ticker dừng lại', (
    tester,
  ) async {
    final service = PerformanceTierService();
    Get.put(service);

    await tester.pumpWidget(
      MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
    );
    await tester.pump();
    expect(SchedulerBinding.instance.transientCallbackCount, 1);

    service.tier.value = PerformanceTier.low;
    await tester.pump();

    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tier quay lại high sau khi đã dừng → ticker chạy lại', (
    tester,
  ) async {
    final service = PerformanceTierService();
    Get.put(service);

    await tester.pumpWidget(
      MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
    );
    await tester.pump();

    service.tier.value = PerformanceTier.low;
    await tester.pump();
    expect(SchedulerBinding.instance.transientCallbackCount, 0);

    service.tier.value = PerformanceTier.high;
    await tester.pump();

    expect(SchedulerBinding.instance.transientCallbackCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BUG: tier=low ngay lúc mount (ticker chưa từng tạo) → sau đó phục hồi '
    'high vẫn phải chạy ticker (không được kẹt tắt vĩnh viễn)',
    (tester) async {
      final service = PerformanceTierService()
        ..tier.value = PerformanceTier.low;
      Get.put(service);

      await tester.pumpWidget(
        MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);

      service.tier.value = PerformanceTier.high;
      await tester.pump();

      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduce Motion vẫn thắng dù PerformanceTierService báo high', (
    tester,
  ) async {
    final service = PerformanceTierService();
    Get.put(service);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
      ),
    );
    await tester.pump();

    expect(SchedulerBinding.instance.transientCallbackCount, 0);

    // Đổi tier khi Reduce Motion đang bật không được bật lại ticker.
    service.tier.value = PerformanceTier.low;
    await tester.pump();
    service.tier.value = PerformanceTier.high;
    await tester.pump();

    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
