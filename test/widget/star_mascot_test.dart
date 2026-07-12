import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/presentation/widgets/star_mascot.dart';

void main() {
  // Regression: eyeH.clamp(size.width * 0.012, eyeH) tự tham chiếu eyeH làm
  // cận trên từng ném RangeError khi blink co nhỏ (crash release trên
  // Samsung S24 Ultra). Pump đủ 1 chu kỳ (2400ms) cho mọi mood để phủ hết
  // giá trị blink có thể xảy ra.
  for (final mood in StarMood.values) {
    testWidgets('mood=$mood renders across full blink cycle without crash', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: StarMascot(mood: mood)));

      for (var i = 0; i < 13; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
