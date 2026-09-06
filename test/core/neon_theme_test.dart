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
}
