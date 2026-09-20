import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';

import 'golden_matrix.dart';

void main() {
  group('defaultGoldenMatrix', () {
    test(
      '7 case cố định: baseline + 1 biến thể mỗi trục (bounded runtime)',
      () {
        final matrix = defaultGoldenMatrix();
        expect(matrix, hasLength(7));
        expect(matrix.map((c) => c.name).toList(), [
          'baseline',
          'dark',
          'locale-vi',
          'rtl',
          'textScale-1.3',
          'textScale-2.0',
          'reducedMotion',
        ]);
        // Đúng 1 trục lệch baseline mỗi case (trừ baseline chính nó).
        final baseline = matrix.first;
        for (final c in matrix.skip(1)) {
          final diffs = [
            c.dark != baseline.dark,
            c.locale != baseline.locale,
            c.rtl != baseline.rtl,
            c.textScale != baseline.textScale,
            c.reducedMotion != baseline.reducedMotion,
          ].where((d) => d).length;
          expect(
            diffs,
            1,
            reason: '${c.name} phải chỉ lệch baseline đúng 1 trục',
          );
        }
      },
    );

    test('textScales tuỳ biến được, số case thay đổi tương ứng', () {
      final matrix = defaultGoldenMatrix(textScales: [1.5]);
      expect(matrix, hasLength(6));
      expect(matrix.map((c) => c.name), contains('textScale-1.5'));
    });
  });

  group('runGoldenMatrix: threading đúng từng trục vào widget con', () {
    testWidgets('mọi case trong defaultGoldenMatrix truyền đúng theme/locale/'
        'direction/scale/reducedMotion — không phải no-op giả', (tester) async {
      for (final c in defaultGoldenMatrix()) {
        late Locale seenLocale;
        late bool seenDark;
        late bool seenRtl;
        late bool seenReducedMotion;
        late double seenScale;
        await runGoldenMatrix(
          tester,
          (context) {
            seenLocale = Localizations.localeOf(context);
            seenDark = NeonTheme.dark;
            seenRtl = Directionality.of(context) == TextDirection.rtl;
            seenReducedMotion = MediaQuery.of(context).disableAnimations;
            seenScale = MediaQuery.of(context).textScaler.scale(100) / 100;
            return const SizedBox(width: 10, height: 10);
          },
          guidelines: const [],
          matrix: [c],
        );
        expect(seenLocale, c.locale, reason: c.name);
        expect(seenDark, c.dark, reason: c.name);
        expect(seenRtl, c.rtl, reason: c.name);
        expect(seenReducedMotion, c.reducedMotion, reason: c.name);
        expect(seenScale, closeTo(c.textScale, 0.001), reason: c.name);
      }
    });

    testWidgets(
      'không mutate NeonTheme.dark sau khi chạy xong dù case cuối là dark',
      (tester) async {
        NeonTheme.dark = false;
        await runGoldenMatrix(
          tester,
          (context) => const SizedBox(width: 10, height: 10),
          guidelines: const [],
          matrix: const [
            GoldenMatrixCase(name: 'a', dark: true),
            GoldenMatrixCase(name: 'b', dark: true),
          ],
        );
        expect(NeonTheme.dark, isFalse);
      },
    );
  });

  group('runGoldenMatrix: fixture bắt lỗi thật (chống false negative)', () {
    testWidgets(
      'báo đúng tên case khi widget overflow, dừng ngay không im lặng bỏ qua',
      (tester) async {
        Object? caught;
        try {
          await runGoldenMatrix(
            tester,
            (context) => const SizedBox(
              width: 40,
              height: 20,
              child: Row(
                children: [
                  SizedBox(width: 30, height: 10),
                  SizedBox(width: 30, height: 10),
                ],
              ),
            ),
            guidelines: const [],
            matrix: const [GoldenMatrixCase(name: 'always-overflows')],
          );
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<TestFailure>());
        expect(caught.toString(), contains('always-overflows'));
      },
    );

    testWidgets('widget không overflow đi qua sạch, không false positive', (
      tester,
    ) async {
      await runGoldenMatrix(
        tester,
        (context) => const SizedBox(width: 100, height: 40),
        guidelines: const [],
        matrix: const [GoldenMatrixCase(name: 'fine')],
      );
      // Không throw tức là pass — assertion thật sự của test này.
    });

    testWidgets('báo lỗi tap target quá nhỏ theo androidTapTargetGuideline', (
      tester,
    ) async {
      Object? caught;
      try {
        await runGoldenMatrix(
          tester,
          (context) => Semantics(
            button: true,
            label: 'tiny button',
            child: GestureDetector(
              onTap: () {},
              child: Container(width: 20, height: 20, color: Colors.red),
            ),
          ),
          matrix: const [GoldenMatrixCase(name: 'tiny-tap-target')],
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
    });

    testWidgets(
      'tap target đủ lớn (48x48) đi qua sạch androidTapTargetGuideline',
      (tester) async {
        await runGoldenMatrix(
          tester,
          (context) => Semantics(
            button: true,
            label: 'ok button',
            child: GestureDetector(
              onTap: () {},
              child: Container(width: 48, height: 48, color: Colors.red),
            ),
          ),
          matrix: const [GoldenMatrixCase(name: 'ok-tap-target')],
        );
      },
    );
  });

  group('runGoldenMatrix: golden file naming ổn định', () {
    testWidgets('so khớp đúng goldens/<base>_<case>.png cho từng case', (
      tester,
    ) async {
      await runGoldenMatrix(
        tester,
        (context) => Container(width: 40, height: 40, color: NeonTheme.cyan),
        goldenBaseName: 'golden_matrix_fixture',
        guidelines: const [],
        matrix: const [
          GoldenMatrixCase(name: 'a'),
          GoldenMatrixCase(name: 'b', dark: true),
        ],
      );
    });
  });
}
