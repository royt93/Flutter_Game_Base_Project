import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/presentation/game/game_session_engine_bridge.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';

Future<void> _settled(WidgetTester tester, RoyGame game) async {
  await game.toBeLoaded();
  await tester.pump();
  await tester.pump();
}

Future<RoyGame> _mount(WidgetTester tester) async {
  final game = RoyGame();
  await tester.pumpWidget(
    MaterialApp(
      home: Material(child: GameWidget(game: game)),
    ),
  );
  await _settled(tester, game);
  return game;
}

void main() {
  tearDown(Get.reset);

  testWidgets('pausing the session freezes the engine; resume restarts it', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSessionController()
      ..markReady()
      ..start();
    final bridge = GameSessionEngineBridge(session: session, game: game);
    addTearDown(bridge.dispose);
    expect(game.paused, isFalse);

    session.pause(GamePauseReason.user);
    expect(game.paused, isTrue);
    final frozen = game.orb.position.clone();
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.orb.position, equals(frozen));

    session.resume(GamePauseReason.user);
    expect(game.paused, isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.orb.position, isNot(equals(frozen)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a session that is already paused pauses the engine at once', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSessionController()
      ..markReady()
      ..start()
      ..pause(GamePauseReason.user);
    final bridge = GameSessionEngineBridge(session: session, game: game);
    addTearDown(bridge.dispose);
    expect(game.paused, isTrue);
  });

  testWidgets('engine stays paused until EVERY pause reason is cleared', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSessionController()
      ..markReady()
      ..start();
    final bridge = GameSessionEngineBridge(session: session, game: game);
    addTearDown(bridge.dispose);

    session.pause(GamePauseReason.user);
    session.pause(GamePauseReason.system);
    session.resume(GamePauseReason.user);
    expect(game.paused, isTrue, reason: 'system pause still active');
    session.resume(GamePauseReason.system);
    expect(game.paused, isFalse);
  });

  testWidgets('app background and foreground pause and resume the engine', (
    tester,
  ) async {
    final game = await _mount(tester);
    final lifecycle = RoyLifecycleCoordinator();
    final session = Get.put(GameSessionController(lifecycle: lifecycle))
      ..markReady()
      ..start();
    final bridge = GameSessionEngineBridge(session: session, game: game);
    addTearDown(bridge.dispose);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.paused, isTrue);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.paused, isFalse);
  });

  testWidgets('restart through ready/start resumes a paused engine', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSessionController()
      ..markReady()
      ..start()
      ..pause(GamePauseReason.user);
    final bridge = GameSessionEngineBridge(session: session, game: game);
    addTearDown(bridge.dispose);
    expect(game.paused, isTrue);

    session
      ..restart()
      ..markReady()
      ..start();
    expect(game.paused, isFalse);
  });

  testWidgets('loading, ready and terminal phases never touch the engine', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSessionController();
    final bridge = GameSessionEngineBridge(session: session, game: game);
    addTearDown(bridge.dispose);

    expect(game.paused, isFalse, reason: 'loading');
    session.markReady();
    expect(game.paused, isFalse, reason: 'ready');
    session.start();
    session.win();
    expect(game.paused, isFalse, reason: 'won');

    // And a game the caller paused on purpose is not resumed by `won`.
    game.pauseEngine();
    final lost = GameSessionController()
      ..markReady()
      ..start()
      ..lose();
    final other = GameSessionEngineBridge(session: lost, game: game);
    addTearDown(other.dispose);
    expect(game.paused, isTrue, reason: 'lost leaves a paused engine alone');
  });

  testWidgets('dispose stops listening and is safe to repeat', (tester) async {
    final game = await _mount(tester);
    final session = GameSessionController()
      ..markReady()
      ..start();
    final bridge = GameSessionEngineBridge(session: session, game: game);
    bridge.dispose();
    bridge.dispose();

    session.pause(GamePauseReason.user);
    expect(game.paused, isFalse, reason: 'disposed bridge must not react');
  });
}
