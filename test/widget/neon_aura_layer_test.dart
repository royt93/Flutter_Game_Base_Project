import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_base_game/core/neon_theme.dart';
import 'package:roy_base_game/presentation/widgets/neon_aura_layer.dart';

void main() {
  testWidgets('does not crash whether the shader loads or fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: NeonAuraLayer(color: NeonTheme.cyan)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
