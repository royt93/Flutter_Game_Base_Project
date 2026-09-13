import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/victory_card_template.dart';

void main() {
  // NeonTheme.dark là 1 static field toàn cục — reset lại sau mỗi test để
  // không rò rỉ giá trị sang các test file khác chạy cùng process.
  tearDown(() => NeonTheme.dark = false);

  testWidgets('renders title, stat lines and avatar when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: VictoryCardTemplate(
            title: 'Level 50 Complete!',
            statLines: const ['Score: 12,340', 'Time: 01:23'],
            avatar: const CircleAvatar(child: Text('RB')),
          ),
        ),
      ),
    );

    expect(find.text('Level 50 Complete!'), findsWidgets);
    expect(find.text('Score: 12,340'), findsOneWidget);
    expect(find.text('Time: 01:23'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QrImageView absent when qrData is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: VictoryCardTemplate(
            title: 'Level 1 Complete!',
            statLines: const ['Score: 100'],
          ),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QrImageView absent when qrData is empty string', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: VictoryCardTemplate(
            title: 'Level 1 Complete!',
            statLines: const ['Score: 100'],
            qrData: '',
          ),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('QrImageView present with given data when qrData is non-empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: VictoryCardTemplate(
            title: 'Level 1 Complete!',
            statLines: const ['Score: 100'],
            qrData: 'https://example.com/invite/abc123',
          ),
        ),
      ),
    );

    // QrImageView's data is private (no public getter), so just confirm one
    // renders and doesn't throw — the encoded string is caller-supplied and
    // covered by the constructor call above.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not crash with minimal required-only constructor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: VictoryCardTemplate(
            title: 'Level 1 Complete!',
            statLines: ['Score: 100'],
          ),
        ),
      ),
    );

    expect(find.text('Level 1 Complete!'), findsWidgets);
    expect(find.byType(QrImageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ENH-34: có entrance animation (scale+fade, easeOutBack, 320ms)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: VictoryCardTemplate(
              title: 'Level 1 Complete!',
              statLines: ['Score: 100'],
            ),
          ),
        ),
      );

      final builder = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(builder.duration, const Duration(milliseconds: 320));
      expect(builder.curve, Curves.easeOutBack);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-34: Reduce Motion bật → entrance animation collapse (duration = 0)',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Material(
              child: VictoryCardTemplate(
                title: 'Level 1 Complete!',
                statLines: ['Score: 100'],
              ),
            ),
          ),
        ),
      );

      final builder = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(builder.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );

  group('BUG-33: QR luôn có nền trắng cố định bất kể NeonTheme.dark', () {
    Container qrBackgroundContainer(WidgetTester tester) {
      return tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(QrImageView),
              matching: find.byType(Container),
            )
            .first,
      );
    }

    testWidgets('NeonTheme.dark = false (mặc định) → nền QR vẫn trắng', (
      tester,
    ) async {
      NeonTheme.dark = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: VictoryCardTemplate(
              title: 'Level 1 Complete!',
              statLines: const ['Score: 100'],
              qrData: 'https://example.com/invite/abc123',
            ),
          ),
        ),
      );

      final decoration =
          qrBackgroundContainer(tester).decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'NeonTheme.dark = true → nền QR VẪN trắng, không đổi theo theme tối '
      '(đây là yêu cầu kỹ thuật của QR, không phải lựa chọn thẩm mỹ)',
      (tester) async {
        NeonTheme.dark = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: VictoryCardTemplate(
                title: 'Level 1 Complete!',
                statLines: const ['Score: 100'],
                qrData: 'https://example.com/invite/abc123',
              ),
            ),
          ),
        );

        final decoration =
            qrBackgroundContainer(tester).decoration as BoxDecoration;
        expect(decoration.color, Colors.white);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'qrData null → không có Container nền trắng thừa (không render QR)',
      (tester) async {
        NeonTheme.dark = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: VictoryCardTemplate(
                title: 'Level 1 Complete!',
                statLines: const ['Score: 100'],
              ),
            ),
          ),
        );

        expect(find.byType(QrImageView), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ENH-39: qrCaption override', () {
    testWidgets('không truyền → giữ nguyên default cũ (Scan to play)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: VictoryCardTemplate(
              title: 'Level 1 Complete!',
              statLines: const ['Score: 100'],
              qrData: 'https://example.com/invite/abc123',
            ),
          ),
        ),
      );

      expect(find.text('Scan to play'), findsOneWidget);
    });

    testWidgets(
      'truyền qrCaption tuỳ chỉnh → hiện đúng chuỗi đó thay vì default',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: VictoryCardTemplate(
                title: 'Level 1 Complete!',
                statLines: const ['Score: 100'],
                qrData: 'https://example.com/invite/abc123',
                qrCaption: 'Quét để chơi',
              ),
            ),
          ),
        );

        expect(find.text('Scan to play'), findsNothing);
        expect(find.text('Quét để chơi'), findsOneWidget);
      },
    );

    testWidgets(
      'qrData null → qrCaption không render (không có QR thì không có caption)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: VictoryCardTemplate(
                title: 'Level 1 Complete!',
                statLines: const ['Score: 100'],
                qrCaption: 'Quét để chơi',
              ),
            ),
          ),
        );

        expect(find.text('Quét để chơi'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
