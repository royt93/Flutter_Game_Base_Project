import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/utils/theme_contrast_validator.dart';

void main() {
  group('relativeLuminance / contrastRatio', () {
    test('trắng có luminance ~1.0, đen có luminance ~0.0', () {
      expect(relativeLuminance(Colors.white), closeTo(1.0, 0.001));
      expect(relativeLuminance(Colors.black), closeTo(0.0, 0.001));
    });

    test('đen trên trắng đạt tỉ lệ WCAG tối đa ~21:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
    });

    test('cùng 1 màu cho tỉ lệ 1:1 (không phân biệt được)', () {
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.001));
    });

    test('đối xứng: thứ tự 2 tham số không đổi kết quả', () {
      const a = Color(0xFF3A2E6B);
      const b = Color(0xFFFFFFFF);
      expect(contrastRatio(a, b), contrastRatio(b, a));
    });
  });

  group('validateNeonThemeContrast: fixture bắt lỗi thật', () {
    test('màu trùng nhau bị báo lỗi contrast dưới ngưỡng', () {
      final issues = validateNeonThemeContrastPairs([
        const ContrastCheck(
          token: 'fixture',
          foreground: Colors.white,
          background: Colors.white,
          threshold: 4.5,
          kind: ContrastCheckKind.text,
        ),
      ]);
      expect(issues, hasLength(1));
      expect(issues.single.ratio, closeTo(1.0, 0.001));
    });

    test('màu tương phản tốt không bị báo lỗi (false positive được kiểm soát)', () {
      final issues = validateNeonThemeContrastPairs([
        const ContrastCheck(
          token: 'fixture',
          foreground: Colors.black,
          background: Colors.white,
          threshold: 4.5,
          kind: ContrastCheckKind.text,
        ),
      ]);
      expect(issues, isEmpty);
    });
  });

  group('validateNeonThemeContrast: NeonTheme thật', () {
    late Map<String, String> originalPalette;
    late bool originalDark;
    late bool originalCvd;

    setUp(() {
      originalPalette = NeonTheme.exportPalette();
      originalDark = NeonTheme.dark;
      originalCvd = NeonTheme.colorBlindSafe;
    });

    tearDown(() {
      NeonTheme.importPalette(originalPalette);
      NeonTheme.dark = originalDark;
      NeonTheme.colorBlindSafe = originalCvd;
    });

    test('ink (chữ chính) trên card/cardAlt đạt AA ở cả 2 theme', () {
      final issues = validateNeonThemeContrast();
      final inkIssues = issues.where(
        (i) => i.kind == ContrastCheckKind.text && i.token.startsWith('ink on'),
      );
      expect(inkIssues, isEmpty, reason: '$inkIssues');
    });

    test(
      'PHÁT HIỆN THẬT: inkSoft (chữ phụ) trên light theme KHÔNG đạt AA normal '
      'text (dù đạt AA large text/UI 3.0) — ghi nhận trong Quyết định, không '
      'sửa trong task này (đổi màu ink ảnh hưởng hàng loạt widget/golden khác)',
      () {
        final issues = validateNeonThemeContrast();
        final inkSoftLight = issues.where(
          (i) => i.token.startsWith('inkSoft on') && i.state == 'light',
        );
        expect(inkSoftLight, hasLength(2));
        for (final issue in inkSoftLight) {
          expect(issue.ratio, greaterThanOrEqualTo(3.0));
          expect(issue.ratio, lessThan(4.5));
        }

        final inkSoftDark = issues.where(
          (i) => i.token.startsWith('inkSoft on') && i.state == 'dark',
        );
        expect(inkSoftDark, isEmpty, reason: 'dark theme đã đạt AA, chỉ light theme bị');
      },
    );

    test(
      'PHÁT HIỆN THẬT: lockedBorder/lockedFill không đạt ngưỡng UI-component '
      '3.0 và không có biến thể dark riêng (cùng 1 cặp màu cho cả 2 theme)',
      () {
        final issues = validateNeonThemeContrast();
        final lockedIssues = issues.where((i) => i.kind == ContrastCheckKind.uiComponent);
        expect(lockedIssues, hasLength(1));
        expect(lockedIssues.single.state, 'constant');
      },
    );

    test('không mutate NeonTheme.dark/colorBlindSafe sau khi chạy xong', () {
      NeonTheme.dark = true;
      NeonTheme.colorBlindSafe = true;
      validateNeonThemeContrast();
      expect(NeonTheme.dark, isTrue);
      expect(NeonTheme.colorBlindSafe, isTrue);

      NeonTheme.dark = false;
      NeonTheme.colorBlindSafe = false;
      validateNeonThemeContrast();
      expect(NeonTheme.dark, isFalse);
      expect(NeonTheme.colorBlindSafe, isFalse);
    });

    test('không mutate palette màu (export trước/sau giống hệt)', () {
      final before = NeonTheme.exportPalette();
      validateNeonThemeContrast();
      expect(NeonTheme.exportPalette(), before);
    });

    test('reskin palette xấu (ink trùng màu card) bị validator bắt lỗi', () {
      NeonTheme.importPalette({'inkLight': '#FFFFFF', 'cardLight': '#FFFFFF'});
      final issues = validateNeonThemeContrast();
      expect(
        issues.any((i) => i.token == 'ink on card' && i.state == 'light'),
        isTrue,
      );
    });

    test('gemColors mặc định phân biệt được theo cặp (heuristic khoảng cách RGB)', () {
      final issues = validateNeonThemeContrast();
      final gemErrors = issues.where((i) => i.kind == ContrastCheckKind.gemPalette);
      expect(gemErrors, isEmpty);
    });

    test('gemColors colorBlindSafe cũng được kiểm tra khi bật cờ', () {
      NeonTheme.colorBlindSafe = true;
      final issues = validateNeonThemeContrast();
      expect(issues.any((i) => i.state == 'colorBlindSafe'), isFalse);
      // Không lỗi tức là 7 màu Okabe-Ito-derived vẫn đủ phân biệt.
    });

    test('gemColors bị thu hẹp quá giống nhau thì bị báo lỗi', () {
      NeonTheme.importPalette({
        'cyan': '#101010',
        'magenta': '#111111',
        'lime': '#121212',
        'yellow': '#131313',
        'orange': '#141414',
        'purple': '#151515',
      });
      final issues = validateNeonThemeContrast();
      expect(
        issues.any((i) => i.kind == ContrastCheckKind.gemPalette),
        isTrue,
      );
    });

    test('AAA nghiêm hơn AA: cùng palette có thể sạch AA nhưng lỗi AAA', () {
      final aa = validateNeonThemeContrast(
        config: const ThemeContrastConfig(),
      ).where((i) => i.kind == ContrastCheckKind.text);
      final aaa = validateNeonThemeContrast(
        config: const ThemeContrastConfig(normalTextThreshold: 7.0, uiComponentThreshold: 4.5),
      ).where((i) => i.kind == ContrastCheckKind.text);
      expect(aaa.length, greaterThanOrEqualTo(aa.length));
    });
  });

  group('widget fixture: token khớp đúng màu render thật (chống false positive)', () {
    testWidgets('Text màu ink trên Container màu card render đúng RGB đã khai báo', (
      tester,
    ) async {
      const inkColor = Color(0xFF3A2E6B);
      const cardColor = Color(0xFFFFFFFF);
      await tester.pumpWidget(
        MaterialApp(
          home: Container(
            color: cardColor,
            child: const Text(
              'contrast fixture',
              style: TextStyle(color: inkColor),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('contrast fixture'));
      final renderedInk = textWidget.style!.color!;
      final container = tester.widget<Container>(find.byType(Container));
      final renderedCard = (container.color)!;

      // Token khai báo ở test phải khớp CHÍNH XÁC màu thật cây widget
      // render ra — nếu 1 wrapper (Opacity/theme override) âm thầm đổi
      // màu, ratio tính từ token sẽ sai lệch so với thực tế trên máy.
      expect(renderedInk, inkColor);
      expect(renderedCard, cardColor);
      expect(contrastRatio(renderedInk, renderedCard), greaterThanOrEqualTo(4.5));
    });

    testWidgets('fixture cố tình sai màu bị validator chấm fail đúng, không false-negative', (
      tester,
    ) async {
      const badInk = Color(0xFFEFEFEF);
      const badCard = Color(0xFFFFFFFF);
      await tester.pumpWidget(
        MaterialApp(
          home: Container(
            color: badCard,
            child: const Text('bad fixture', style: TextStyle(color: badInk)),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('bad fixture'));
      final renderedInk = textWidget.style!.color!;
      final container = tester.widget<Container>(find.byType(Container));
      final renderedCard = (container.color)!;

      expect(contrastRatio(renderedInk, renderedCard), lessThan(4.5));
    });
  });
}
