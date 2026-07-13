import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/game/block_component.dart';

/// Vẽ trực tiếp qua [paintTileBody] (không cần dựng Flame game) — I17 AC:
/// "3 variant render khác nhau rõ, cùng màu vẫn phân biệt được world".
class _TilePainter extends CustomPainter {
  _TilePainter(this.material);

  final TileMaterial material;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    const inset = 6.0;
    final rect = Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2);
    final radius = Radius.circular(
      s *
          switch (material) {
            TileMaterial.jelly => 0.22,
            TileMaterial.crystal => 0.10,
            TileMaterial.metal => 0.16,
          },
    );
    final rrect = RRect.fromRectAndRadius(rect, radius);
    paintTileBody(canvas, rrect, rect, s, Colors.pinkAccent, material);
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) => false;
}

Widget _wrap(TileMaterial material, Key key) => MaterialApp(
  home: Material(
    child: Center(
      child: SizedBox(
        width: 80,
        height: 80,
        child: CustomPaint(key: key, painter: _TilePainter(material)),
      ),
    ),
  ),
);

void main() {
  for (final material in TileMaterial.values) {
    testWidgets('BlockComponent material ${material.name}', (tester) async {
      const key = Key('tile');
      await tester.pumpWidget(_wrap(material, key));
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('block_material_${material.name}.png'),
      );
    });
  }
}
