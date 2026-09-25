import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/onboarding_coordinator_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
    Get.put(ConsentStateService(policyVersion: 1), permanent: true);
    Get.put(OnboardingCoordinatorService(), permanent: true);
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets(
    'chưa xem lần nào -> tự hiện dialog, "Chấp nhận tất cả" -> grant hết '
    'category + markFlowSeen',
    (tester) async {
      await tester.pumpWidget(wrap(const ConsentBanner(child: Text('home'))));
      await tester.pumpAndSettle();

      expect(
        find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
        findsOneWidget,
      );

      await tester.tap(find.text('Chấp nhận tất cả'));
      await tester.pumpAndSettle();

      final consent = ConsentStateService.maybe!;
      expect(consent.isGranted(ConsentCategory.analytics), isTrue);
      expect(consent.isGranted(ConsentCategory.personalization), isTrue);
      expect(
        OnboardingCoordinatorService.maybe!.isFlowSeen('consent_banner'),
        isTrue,
      );
    },
  );

  testWidgets(
    '"Từ chối tất cả" -> deny hết category, KHÔNG grant category nào',
    (tester) async {
      await tester.pumpWidget(wrap(const ConsentBanner(child: Text('home'))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Từ chối tất cả'));
      await tester.pumpAndSettle();

      final consent = ConsentStateService.maybe!;
      expect(consent.isGranted(ConsentCategory.analytics), isFalse);
      expect(consent.isGranted(ConsentCategory.personalization), isFalse);
      expect(consent.statusOf(ConsentCategory.analytics), ConsentStatus.denied);
      expect(
        OnboardingCoordinatorService.maybe!.isFlowSeen('consent_banner'),
        isTrue,
      );
    },
  );

  testWidgets('đã markFlowSeen từ trước -> KHÔNG hiện dialog lại nữa', (
    tester,
  ) async {
    OnboardingCoordinatorService.maybe!.markFlowSeen('consent_banner');
    await OnboardingCoordinatorService.maybe!.debugPendingSaves;

    await tester.pumpWidget(wrap(const ConsentBanner(child: Text('home'))));
    await tester.pumpAndSettle();

    expect(
      find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
      findsNothing,
    );
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
    'hiện lần đầu, chấp nhận rồi -> build lại widget mới KHÔNG hiện lại '
    'dialog lần 2 (dùng lại OnboardingCoordinatorService, không tự chế cờ '
    'mới)',
    (tester) async {
      await tester.pumpWidget(wrap(const ConsentBanner(child: Text('home'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chấp nhận tất cả'));
      await tester.pumpAndSettle();

      // Dựng lại y hệt banner này ở 1 cây widget MỚI (giả lập app restart
      // trong cùng process test) — chỉ đọc lại state đã persist qua
      // OnboardingCoordinatorService, không phải cờ nội bộ của widget cũ.
      await tester.pumpWidget(wrap(const ConsentBanner(child: Text('home 2'))));
      await tester.pumpAndSettle();

      expect(
        find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'không có OnboardingCoordinatorService đăng ký -> vẫn hiện dialog, '
    'không crash',
    (tester) async {
      Get.delete<OnboardingCoordinatorService>();

      await tester.pumpWidget(wrap(const ConsentBanner(child: Text('home'))));
      await tester.pumpAndSettle();

      expect(
        find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
        findsOneWidget,
      );
      await tester.tap(find.text('Chấp nhận tất cả'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        ConsentStateService.maybe!.isGranted(ConsentCategory.analytics),
        isTrue,
      );
    },
  );

  group('BUG-77: policy version / flowId dynamic updates', () {
    testWidgets(
      'đổi version từ 1 lên 2 trên cùng State -> hiện lại dialog và markFlowSeen version 2',
      (tester) async {
        await tester.pumpWidget(
          wrap(const ConsentBanner(version: 1, child: Text('home'))),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
          findsOneWidget,
        );
        await tester.tap(find.text('Chấp nhận tất cả'));
        await tester.pumpAndSettle();

        expect(
          OnboardingCoordinatorService.maybe!.isFlowSeen(
            'consent_banner',
            version: 1,
          ),
          isTrue,
        );
        expect(
          OnboardingCoordinatorService.maybe!.isFlowSeen(
            'consent_banner',
            version: 2,
          ),
          isFalse,
        );

        // Rebuild trên cùng State (cùng vị trí trong widget tree) với version 2
        await tester.pumpWidget(
          wrap(const ConsentBanner(version: 2, child: Text('home'))),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
          findsOneWidget,
        );
        await tester.tap(find.text('Chấp nhận tất cả'));
        await tester.pumpAndSettle();

        expect(
          OnboardingCoordinatorService.maybe!.isFlowSeen(
            'consent_banner',
            version: 2,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'rebuild cùng State nhưng version/flowId KHÔNG đổi -> KHÔNG hiện dialog lại',
      (tester) async {
        await tester.pumpWidget(
          wrap(const ConsentBanner(version: 1, child: Text('home 1'))),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chấp nhận tất cả'));
        await tester.pumpAndSettle();

        // Rebuild parent với child khác nhưng cùng config ConsentBanner
        await tester.pumpWidget(
          wrap(const ConsentBanner(version: 1, child: Text('home 2'))),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
          findsNothing,
        );
        expect(find.text('home 2'), findsOneWidget);
      },
    );

    testWidgets('đổi flowId trên cùng State -> hiện dialog cho flow mới', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const ConsentBanner(flowId: 'flow_a', child: Text('home'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chấp nhận tất cả'));
      await tester.pumpAndSettle();

      expect(OnboardingCoordinatorService.maybe!.isFlowSeen('flow_a'), isTrue);
      expect(OnboardingCoordinatorService.maybe!.isFlowSeen('flow_b'), isFalse);

      // Rebuild trên cùng State với flowId khác
      await tester.pumpWidget(
        wrap(const ConsentBanner(flowId: 'flow_b', child: Text('home'))),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Chúng tôi coi trọng quyền riêng tư của bạn'),
        findsOneWidget,
      );
      await tester.tap(find.text('Chấp nhận tất cả'));
      await tester.pumpAndSettle();

      expect(OnboardingCoordinatorService.maybe!.isFlowSeen('flow_b'), isTrue);
    });
  });
}
