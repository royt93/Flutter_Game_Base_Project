import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/presentation/widgets/common/async_common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/retry_error_state.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? clipboardText;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
  });

  testWidgets('hiện icon/title/message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const RetryErrorState(
          icon: Icons.wifi_off,
          title: 'Không có mạng',
          message: 'Kiểm tra kết nối rồi thử lại.',
        ),
      ),
    );

    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('Không có mạng'), findsOneWidget);
    expect(find.text('Kiểm tra kết nối rồi thử lại.'), findsOneWidget);
  });

  testWidgets(
    'không có onRetry: không hiện nút retry nào (không giả tương tác)',
    (tester) async {
      await tester.pumpWidget(_wrap(const RetryErrorState(message: 'Lỗi.')));

      expect(find.byType(AsyncCommonButton), findsNothing);
    },
  );

  testWidgets('có onRetry: bấm gọi đúng 1 lần, rapid tap không chạy trùng', (
    tester,
  ) async {
    var callCount = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        RetryErrorState(
          message: 'Lỗi.',
          onRetry: () {
            callCount++;
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(AsyncCommonButton));
    await tester.tap(find.byType(AsyncCommonButton));
    await tester.pump();

    expect(callCount, 1);
    completer.complete();
    await tester.pump();
  });

  testWidgets('extraAction: hiện đúng widget phụ (vd "Open settings")', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RetryErrorState(
          message: 'Không có mạng.',
          extraAction: TextButton(
            onPressed: () {},
            child: const Text('Open settings'),
          ),
        ),
      ),
    );

    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('không có code: không hiện hàng diagnostic code', (tester) async {
    await tester.pumpWidget(_wrap(const RetryErrorState(message: 'Lỗi.')));

    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('có code: hiện đúng, bấm vào copy vào clipboard', (tester) async {
    await tester.pumpWidget(
      _wrap(const RetryErrorState(message: 'Lỗi.', code: 'NETWORK-ABC123')),
    );

    expect(find.text('NETWORK-ABC123'), findsOneWidget);

    await tester.tap(find.text('NETWORK-ABC123'));
    await tester.pump();

    final data = await Clipboard.getData('text/plain');
    expect(data?.text, 'NETWORK-ABC123');

    // ToastBanner.show's OverlayEntry runs its own AnimationController
    // (entrance + hold + exit) — phải pump hết vòng đời để nó tự dispose,
    // không thì Ticker còn sống sẽ làm TEST SAU trong cùng file báo lỗi
    // "animation still running" (đúng convention toast_banner_test.dart).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 250));
  });

  group('fromSdkFailure', () {
    test('map đúng icon/title theo kind, message lấy từ failure.message', () {
      const failure = SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Không thể kết nối máy chủ.',
      );
      final state = RetryErrorState.fromSdkFailure(failure);

      expect(state.message, 'Không thể kết nối máy chủ.');
      expect(state.icon, isNotNull);
    });

    test('diagnostic code ổn định: cùng kind+message luôn ra cùng code', () {
      const failure = SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Không lưu được.',
      );
      final a = RetryErrorState.fromSdkFailure(failure);
      final b = RetryErrorState.fromSdkFailure(failure);

      expect(a.code, isNotNull);
      expect(a.code, b.code);
    });

    test('kind/message khác nhau ra code khác nhau', () {
      final a = RetryErrorState.fromSdkFailure(
        const SdkFailure(kind: SdkErrorKind.network, message: 'x'),
      );
      final b = RetryErrorState.fromSdkFailure(
        const SdkFailure(kind: SdkErrorKind.storage, message: 'x'),
      );

      expect(a.code, isNot(b.code));
    });

    test('không bao giờ lộ cause/stackTrace vào message hiển thị', () {
      final failure = SdkFailure(
        kind: SdkErrorKind.unknown,
        message: 'Đã xảy ra lỗi.',
        cause: Exception('SECRET_INTERNAL_DETAIL'),
        stackTrace: StackTrace.current,
      );
      final state = RetryErrorState.fromSdkFailure(failure);

      expect(state.message, isNot(contains('SECRET_INTERNAL_DETAIL')));
      expect(state.message, 'Đã xảy ra lỗi.');
    });

    test('onRetry truyền qua đúng', () async {
      var retried = false;
      final state = RetryErrorState.fromSdkFailure(
        const SdkFailure(kind: SdkErrorKind.network, message: 'x'),
        onRetry: () async => retried = true,
      );

      await state.onRetry!();
      expect(retried, isTrue);
    });
  });

  testWidgets('compact: không tự bọc Center (caller tự đặt vị trí)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RetryErrorState(message: 'Lỗi.', compact: true)),
    );

    expect(
      find.ancestor(
        of: find.byType(RetryErrorState),
        matching: find.byType(Center),
      ),
      findsNothing,
    );
  });

  testWidgets('fullscreen (mặc định): tự bọc Center', (tester) async {
    await tester.pumpWidget(_wrap(const RetryErrorState(message: 'Lỗi.')));

    expect(
      find.descendant(
        of: find.byType(RetryErrorState),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });

  testWidgets('RTL + text scale lớn không throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Material(
              child: RetryErrorState(
                message: 'Lỗi.',
                code: 'X-1',
                onRetry: () async {},
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
