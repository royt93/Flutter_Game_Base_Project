import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit_example/game/match3_engine.dart';

List<int> _board() => List.generate(
  Match3Engine.cellCount,
  (index) => (index + index ~/ Match3Engine.width) % Match3Engine.tileKinds,
);

void main() {
  test(
    'generated boards have no initial match and at least one legal swap',
    () {
      for (var seed = 0; seed < 100; seed++) {
        final game = Match3Engine(random: math.Random(seed));
        expect(game.board, hasLength(36));
        expect(game.board.every((tile) => tile >= 0 && tile < 5), isTrue);
        var playable = false;
        for (
          var index = 0;
          index < Match3Engine.cellCount && !playable;
          index++
        ) {
          for (final neighbor in [index + 1, index + Match3Engine.width]) {
            if (neighbor >= Match3Engine.cellCount ||
                (neighbor == index + 1 &&
                    index % Match3Engine.width == Match3Engine.width - 1)) {
              continue;
            }
            final copy = Match3Engine(
              random: math.Random(seed),
              initialBoard: game.board,
            );
            playable |= copy.swap(index, neighbor);
          }
        }
        expect(playable, isTrue, reason: 'seed $seed should be playable');
      }

      final a = Match3Engine(random: math.Random(17));
      final b = Match3Engine(random: math.Random(17));
      expect(a.board, b.board);
    },
  );

  test('shuffle repairs a board with no legal swaps', () {
    final game = Match3Engine(random: math.Random(1), initialBoard: _board());
    expect(game.hasLegalMove, isFalse);
    game.shuffle();
    expect(game.hasLegalMove, isTrue);
    expect(game.board, hasLength(Match3Engine.cellCount));
  });

  test('non-adjacent swaps are rejected without mutating board', () {
    final game = Match3Engine(initialBoard: _board());
    final before = game.board;
    expect(game.swap(0, 2), isFalse);
    expect(game.board, before);
    expect(game.moves, 20);
  });

  test('invalid adjacent swap reverts board and preserves move', () {
    final game = Match3Engine(initialBoard: _board());
    final before = game.board;
    expect(game.swap(0, 1), isFalse);
    expect(game.board, before);
    expect(game.moves, 20);
  });

  test('valid swap clears match, scores, cascades, and refills board', () {
    final board = _board();
    // Row 1 becomes 0-0-0 after swapping index 8 with index 9.
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(random: math.Random(31), initialBoard: board);
    expect(game.swap(8, 9), isTrue);
    expect(game.moves, 19);
    expect(game.score, greaterThanOrEqualTo(30));
    expect(game.board, hasLength(36));
    expect(game.board.every((tile) => tile >= 0 && tile < 5), isTrue);
  });

  test('twentieth accepted move ends run when score goal was not reached', () {
    final board = _board();
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      random: math.Random(1),
      initialBoard: board,
      score: 0,
      moves: 1,
      status: Match3Status.playing,
    );
    expect(game.swap(8, 9), isTrue);
    expect(game.status, Match3Status.lost);
    expect(game.swap(8, 9), isFalse);
  });

  test('score goal ends run immediately', () {
    final board = _board();
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      random: math.Random(1),
      initialBoard: board,
      score: 480,
      status: Match3Status.playing,
    );
    expect(game.swap(8, 9), isTrue);
    expect(game.status, Match3Status.won);
    expect(game.score, greaterThanOrEqualTo(500));
  });

  test('rejects initial boards that already contain a match', () {
    final board = _board();
    board[0] = board[1];
    board[2] = board[1];
    expect(() => Match3Engine(initialBoard: board), throwsArgumentError);
  });

  test('reset starts a fresh run', () {
    final game = Match3Engine(initialBoard: _board());
    game.reset();
    expect(game.moves, 20);
    expect(game.score, 0);
    expect(game.status, Match3Status.ready);
    expect(game.lastSwap, isNull);
  });
}
