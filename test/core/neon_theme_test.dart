import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';

void main() {
  testWidgets('reducedMotion đọc đúng MediaQuery.disableAnimations', (
    tester,
  ) async {
    late BuildContext onCtx;
    late BuildContext offCtx;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            onCtx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(NeonTheme.reducedMotion(onCtx), isTrue);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: Builder(
          builder: (context) {
            offCtx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(NeonTheme.reducedMotion(offCtx), isFalse);
  });

  group('exportPalette / importPalette', () {
    late Map<String, String> original;

    setUp(() => original = NeonTheme.exportPalette());
    tearDown(() => NeonTheme.importPalette(original));

    test('round trip: export -> mutate -> import restores original color', () {
      final before = NeonTheme.cyan;
      NeonTheme.cyan = const Color(0xFF123456);
      expect(NeonTheme.cyan, const Color(0xFF123456));

      NeonTheme.importPalette(original);
      expect(NeonTheme.cyan, before);
    });

    test('partial import overrides only given keys, others untouched', () {
      final redBefore = NeonTheme.red;
      NeonTheme.importPalette({
        'cyan': '#111111',
        'magenta': '#222222',
        'lime': '#333333',
        'yellow': '#444444',
        'orange': '#555555',
        'purple': '#666666',
      });

      expect(NeonTheme.cyan, const Color(0xFF111111));
      expect(NeonTheme.magenta, const Color(0xFF222222));
      expect(NeonTheme.lime, const Color(0xFF333333));
      expect(NeonTheme.yellow, const Color(0xFF444444));
      expect(NeonTheme.orange, const Color(0xFF555555));
      expect(NeonTheme.purple, const Color(0xFF666666));
      expect(NeonTheme.red, redBefore); // untouched by partial import
    });

    test('unknown keys and garbage values are ignored without throwing', () {
      final before = NeonTheme.exportPalette();

      expect(
        () => NeonTheme.importPalette({
          'notARealKey': '#FFFFFF',
          'cyan': 'not-a-hex-color',
          'muted': 123, // wrong type, not a String
        }),
        returnsNormally,
      );

      expect(NeonTheme.exportPalette(), before);
    });

    test(
      'exportPalette returns #RRGGBB hex strings, gemColors reflects live overrides',
      () {
        final exported = NeonTheme.exportPalette();
        expect(exported['muted'], matches(RegExp(r'^#[0-9A-F]{6}$')));
        expect(exported['cyan'], '#35C4F0');

        NeonTheme.cyan = const Color(0xFF00FF00);
        expect(NeonTheme.gemColors.first, const Color(0xFF00FF00));
      },
    );
  });

  group('color blind safe palette', () {
    tearDown(() => NeonTheme.colorBlindSafe = false);

    test('switches gemColors to seven stable CVD-safe colors', () {
      final defaultColors = NeonTheme.gemColors;
      NeonTheme.colorBlindSafe = true;

      expect(NeonTheme.gemColors, NeonTheme.colorBlindSafeGemColors);
      expect(NeonTheme.gemColors, hasLength(7));
      expect(NeonTheme.gemColors, isNot(defaultColors));
      expect(NeonTheme.gemColors.toSet(), hasLength(7));
    });

    test('safe palette keeps a visible RGB distance between every pair', () {
      final colors = NeonTheme.colorBlindSafeGemColors;
      for (var i = 0; i < colors.length; i++) {
        for (var j = i + 1; j < colors.length; j++) {
          final a = colors[i].toARGB32();
          final b = colors[j].toARGB32();
          final distance =
              ((a >> 16 & 0xff) - (b >> 16 & 0xff)).abs() +
              ((a >> 8 & 0xff) - (b >> 8 & 0xff)).abs() +
              ((a & 0xff) - (b & 0xff)).abs();
          expect(distance, greaterThan(45));
        }
      }
    });
  });
}
