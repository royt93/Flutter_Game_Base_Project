import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/notification_permission_primer.dart';

void main() {
  Widget wrap(WidgetBuilder builder) =>
      MaterialApp(home: Builder(builder: builder));

  testWidgets('accept -> gọi đúng onAccept thật, KHÔNG gọi onDecline', (
    tester,
  ) async {
    var acceptCalls = 0;
    var declineCalls = 0;
    NotificationPermissionPrimerChoice? result;

    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await showNotificationPermissionPrimer(
              context,
              onAccept: () async => acceptCalls++,
              onDecline: () async => declineCalls++,
            );
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bật thông báo để không bỏ lỡ phần thưởng?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Bật thông báo'));
    await tester.pumpAndSettle();

    expect(acceptCalls, 1);
    expect(declineCalls, 0);
    expect(result, NotificationPermissionPrimerChoice.accepted);
  });

  testWidgets(
    'decline -> KHÔNG gọi onAccept (không đụng native permission) dưới '
    'bất kỳ hình thức nào',
    (tester) async {
      var acceptCalls = 0;
      var declineCalls = 0;
      NotificationPermissionPrimerChoice? result;

      await tester.pumpWidget(
        wrap(
          (context) => ElevatedButton(
            onPressed: () async {
              result = await showNotificationPermissionPrimer(
                context,
                onAccept: () async => acceptCalls++,
                onDecline: () async => declineCalls++,
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(acceptCalls, 0);
      expect(declineCalls, 1);
      expect(result, NotificationPermissionPrimerChoice.declined);
    },
  );

  testWidgets(
    'decline -> vẫn hoạt động bình thường khi onDecline không được truyền',
    (tester) async {
      var acceptCalls = 0;

      await tester.pumpWidget(
        wrap(
          (context) => ElevatedButton(
            onPressed: () => showNotificationPermissionPrimer(
              context,
              onAccept: () async => acceptCalls++,
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(acceptCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back/gesture đóng dialog (không bấm nút nào) -> dismissed, KHÔNG gọi '
    'onAccept lẫn onDecline',
    (tester) async {
      var acceptCalls = 0;
      var declineCalls = 0;
      NotificationPermissionPrimerChoice? result;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        wrap((context) {
          capturedContext = context;
          return ElevatedButton(
            onPressed: () async {
              result = await showNotificationPermissionPrimer(
                context,
                onAccept: () async => acceptCalls++,
                onDecline: () async => declineCalls++,
              );
            },
            child: const Text('open'),
          );
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Navigator.of(capturedContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(result, NotificationPermissionPrimerChoice.dismissed);
      expect(acceptCalls, 0);
      expect(declineCalls, 0);
    },
  );

  testWidgets('label + message tuỳ chỉnh được dùng đúng thay vì mặc định', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () => showNotificationPermissionPrimer(
            context,
            onAccept: () async {},
            title: 'Custom title',
            message: 'Custom message',
            acceptLabel: 'Yes',
            declineLabel: 'No',
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Custom title'), findsOneWidget);
    expect(find.text('Custom message'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });
}
