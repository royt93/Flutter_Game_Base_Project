import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';

/// Minimal smoke test proving `flame`'s FlameGame/Component/GameWidget wiring
/// actually works end-to-end in this package (see FEAT-14 — the dependency
/// was declared but never exercised). Not a real game, no need for the
/// `flame_test` harness: a plain `GameWidget` inside `Material` + a bounded
/// `pump()` is enough (avoid `pumpAndSettle()` — like `NeonBg`, Flame's game
/// loop runs a permanent `Ticker` that never settles).
void main() {
  testWidgets('builds inside a GameWidget without throwing', (tester) async {
    final game = RoyGame();

    await tester.pumpWidget(
      MaterialApp(home: Material(child: GameWidget(game: game))),
    );
    await game.toBeLoaded();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the circle toggles its tapped state', (tester) async {
    final game = RoyGame();

    await tester.pumpWidget(
      MaterialApp(home: Material(child: GameWidget(game: game))),
    );
    await game.toBeLoaded();
    await tester.pump();

    final before = game.circle.tapped;

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
    // Bounded pump, not pumpAndSettle: Flame's game loop runs a permanent
    // Ticker (like NeonBg — see CLAUDE.md). This also flushes the
    // long-press-vs-tap gesture arena's internal timer so no Timer is left
    // pending at tearDown.
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.circle.tapped, isNot(equals(before)));
    expect(tester.takeException(), isNull);
  });
}
