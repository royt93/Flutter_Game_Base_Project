import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/smart_review_funnel.dart';

void main() {
  Widget wrap(WidgetBuilder builder) =>
      MaterialApp(home: Builder(builder: builder));

  testWidgets(
    '"Thích" -> trigger đúng showReview thật, KHÔNG mở dialog góp ý',
    (tester) async {
      var showReviewCalls = 0;
      SmartReviewFunnelChoice? result;

      await tester.pumpWidget(
        wrap(
          (context) => ElevatedButton(
            onPressed: () async {
              result = await showSmartReviewFunnel(
                context,
                showReview: () async => showReviewCalls++,
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn có thích game không?'), findsOneWidget);

      await tester.tap(find.text('Thích ❤️'));
      await tester.pumpAndSettle();

      expect(showReviewCalls, 1);
      expect(result, SmartReviewFunnelChoice.liked);
      expect(find.text('Điều gì khiến bạn chưa hài lòng?'), findsNothing);
    },
  );

  testWidgets(
    '"Chưa thích" -> KHÔNG mở store review, thay vào đó mở dialog góp ý nội bộ',
    (tester) async {
      var showReviewCalls = 0;
      SmartReviewFunnelChoice? result;

      await tester.pumpWidget(
        wrap(
          (context) => ElevatedButton(
            onPressed: () async {
              result = await showSmartReviewFunnel(
                context,
                showReview: () async => showReviewCalls++,
              );
            },
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chưa thích 💔'));
      await tester.pumpAndSettle();

      expect(showReviewCalls, 0);
      expect(find.text('Điều gì khiến bạn chưa hài lòng?'), findsOneWidget);

      await tester.tap(find.text('Gửi góp ý'));
      await tester.pumpAndSettle();

      expect(result, SmartReviewFunnelChoice.disliked);
      expect(showReviewCalls, 0);
    },
  );

  testWidgets(
    '"Chưa thích" rồi gửi góp ý -> onFeedback nhận đúng text đã nhập',
    (tester) async {
      String? capturedFeedback;

      await tester.pumpWidget(
        wrap(
          (context) => ElevatedButton(
            onPressed: () => showSmartReviewFunnel(
              context,
              showReview: () async {},
              onFeedback: (feedback) async => capturedFeedback = feedback,
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chưa thích 💔'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('smartReviewFunnelFeedbackField')),
        'thiếu tính năng X',
      );
      await tester.tap(find.text('Gửi góp ý'));
      await tester.pumpAndSettle();

      expect(capturedFeedback, 'thiếu tính năng X');
    },
  );

  testWidgets(
    'không có onFeedback -> gửi góp ý vẫn đóng bình thường, không crash',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          (context) => ElevatedButton(
            onPressed: () =>
                showSmartReviewFunnel(context, showReview: () async {}),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chưa thích 💔'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi góp ý'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Điều gì khiến bạn chưa hài lòng?'), findsNothing);
    },
  );

  testWidgets(
    'back/gesture đóng dialog đầu (không bấm nút nào) -> dismissed, KHÔNG '
    'mở store lẫn dialog góp ý',
    (tester) async {
      var showReviewCalls = 0;
      SmartReviewFunnelChoice? result;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        wrap((context) {
          capturedContext = context;
          return ElevatedButton(
            onPressed: () async {
              result = await showSmartReviewFunnel(
                context,
                showReview: () async => showReviewCalls++,
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

      expect(result, SmartReviewFunnelChoice.dismissed);
      expect(showReviewCalls, 0);
      expect(find.text('Điều gì khiến bạn chưa hài lòng?'), findsNothing);
    },
  );

  testWidgets('label tuỳ chỉnh được dùng đúng thay vì mặc định', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () => showSmartReviewFunnel(
            context,
            showReview: () async {},
            title: 'Custom title',
            likeLabel: 'Yes',
            dislikeLabel: 'No',
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Custom title'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });
}
