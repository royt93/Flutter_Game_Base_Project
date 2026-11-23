import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';
import 'package:roy_casual_kit/core/match3_engine.dart';

final _classic = Match3Config.classic;

List<int> _board() => List.generate(
  _classic.cellCount,
  (index) => (index + index ~/ _classic.width) % _classic.tileKinds,
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
        for (var index = 0; index < _classic.cellCount && !playable; index++) {
          for (final neighbor in [index + 1, index + _classic.width]) {
            if (neighbor >= _classic.cellCount ||
                (neighbor == index + 1 &&
                    index % _classic.width == _classic.width - 1)) {
              continue;
            }
            final copy = Match3Engine(
              random: math.Random(seed),
              initialBoard: game.board,
            );
            playable |= copy.swap(index, neighbor) != null;
          }
        }
        expect(playable, isTrue, reason: 'seed $seed should be playable');
      }

      final a = Match3Engine(random: math.Random(17));
      final b = Match3Engine(random: math.Random(17));
      expect(a.board, b.board);
    },
  );

  test('five levels use selected score goals and move limits', () {
    expect(Match3Level.levels.map((level) => level.scoreGoal), [
      1200,
      1370,
      1380,
      1390,
      1420,
    ]);
    expect(Match3Level.levels.map((level) => level.moves), [
      20,
      20,
      19,
      19,
      18,
    ]);
    expect(() => _classic.levelFor(0), throwsArgumentError);
    expect(() => _classic.levelFor(6), throwsArgumentError);
  });

  test('level goal and move limit decide run outcome', () {
    final board = _board();
    board[6] = 0;
    board[7] = 0;
    board[8] = 1;
    board[9] = 0;
    final game = Match3Engine(
      initialBoard: board,
      score: 1350,
      moves: 20,
      status: Match3Status.playing,
      level: 2,
    );
    expect(game.scoreGoal, 1370);
    expect(game.moveLimit, 20);
    game.swap(8, 9);
    expect(game.status, Match3Status.won);
  });

  test('reset applies each level move limit and goal', () {
    final game = Match3Engine(random: math.Random(3));
    for (final level in Match3Level.levels) {
      game.reset(level: level.number);
      expect(game.level, level.number);
      expect(game.moves, level.moves);
      expect(game.scoreGoal, level.scoreGoal);
      expect(game.status, Match3Status.ready);
    }
  });

  test('shuffle repairs a board with no legal swaps', () {
    final game = Match3Engine(random: math.Random(1), initialBoard: _board());
    expect(game.hasLegalMove, isFalse);
    game.shuffle();
    expect(game.hasLegalMove, isTrue);
    expect(game.board, hasLength(_classic.cellCount));
  });

  test('non-adjacent swaps are rejected without mutating board', () {
    final game = Match3Engine(initialBoard: _board());
    final before = game.board;
    expect(game.swap(0, 2), isNull);
    expect(game.board, before);
    expect(game.moves, 20);
  });

  test('invalid adjacent swap reverts board and preserves move', () {
    final game = Match3Engine(initialBoard: _board());
    final before = game.board;
    expect(game.swap(0, 1), isNull);
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
    final steps = game.swap(8, 9);
    expect(steps, isNotNull);
    expect(steps, isNotEmpty);
    expect(steps!.first.matched, containsAll([6, 7, 8]));
    expect(steps.first.cascadeIndex, 1);
    expect(steps.first.scoreGained, greaterThanOrEqualTo(30));
    expect(steps.first.boardBefore[8], 0);
    expect(steps.first.boardBefore[9], 1);
    expect(steps.first.boardBefore[6], 0);
    game.revealCascadeStep(steps.first);
    expect(game.board[6], -1);
    game.showResolvedBoard();
    expect(game.board.every((tile) => tile >= 0), isTrue);
    expect(steps.first.boardAfterRefill, hasLength(_classic.cellCount));
    expect(
      steps.every((step) => step.boardAfterRefill.every((v) => v >= 0)),
      isTrue,
    );
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
    expect(game.swap(8, 9), isNotNull);
    expect(game.status, Match3Status.lost);
    expect(game.swap(8, 9), isNull);
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
      score: 1170,
      status: Match3Status.playing,
    );
    expect(game.swap(8, 9), isNotNull);
    expect(game.status, Match3Status.won);
    expect(game.score, greaterThanOrEqualTo(1200));
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

  group('Match3Config', () {
    test('rejects invalid shape and level tables (release-mode safe)', () {
      expect(() => Match3Config(width: 2), throwsArgumentError);
      expect(() => Match3Config(tileKinds: 2), throwsArgumentError);
      expect(() => Match3Config(pointsPerTile: 0), throwsArgumentError);
      expect(() => Match3Config(levels: const []), throwsArgumentError);
      expect(
        () => Match3Config(
          levels: const [Match3Level(number: 2, scoreGoal: 10, moves: 5)],
        ),
        throwsArgumentError,
      );
      expect(
        () => Match3Config(
          levels: const [Match3Level(number: 1, scoreGoal: 10, moves: 0)],
        ),
        throwsArgumentError,
      );
    });

    test('custom 8x8, 6 tiles, own levels: valid playable boards', () {
      final config = Match3Config(
        width: 8,
        tileKinds: 6,
        pointsPerTile: 5,
        levels: const [Match3Level(number: 1, scoreGoal: 300, moves: 12)],
      );
      for (var seed = 0; seed < 50; seed++) {
        final game = Match3Engine(config: config, random: math.Random(seed));
        expect(game.board, hasLength(64), reason: 'seed $seed');
        expect(game.board.every((t) => t >= 0 && t < 6), isTrue);
        expect(game.hasLegalMove, isTrue, reason: 'seed $seed');
        expect(game.moves, 12);
        expect(game.scoreGoal, 300);
      }
      expect(() => Match3Engine(config: config, level: 2), throwsArgumentError);
    });

    test('initialBoard length is checked against the configured size', () {
      final config = Match3Config(width: 4, tileKinds: 4);
      expect(
        () => Match3Engine(config: config, initialBoard: _board()),
        throwsArgumentError,
      );
    });
  });

  group('useBooster', () {
    Match3Engine fresh({int moves = 20, int level = 1}) => Match3Engine(
      random: math.Random(7),
      initialBoard: _board(),
      moves: moves,
      status: moves < 20 ? Match3Status.playing : Match3Status.ready,
      level: level,
    );

    test('does not spend a move; scores cleared tiles', () {
      final game = fresh();
      final steps = game.useBooster(Match3Booster.rowClear, 14);
      expect(steps, isNotNull);
      expect(game.moves, 20);
      expect(game.score, greaterThan(0));
      expect(game.status, Match3Status.playing);
      expect(steps!.first.matched, {12, 13, 14, 15, 16, 17});
      expect(steps.first.scoreGained, 6 * 10);
      game.showResolvedBoard();
      expect(game.board.every((t) => t >= 0 && t < 5), isTrue);
    });

    test('column clear and bomb clear exactly their area', () {
      final column = fresh().useBooster(Match3Booster.columnClear, 14);
      expect(column!.first.matched, {2, 8, 14, 20, 26, 32});

      final center = fresh().useBooster(Match3Booster.bomb, 14);
      expect(center!.first.matched, {7, 8, 9, 13, 14, 15, 19, 20, 21});

      final corner = fresh().useBooster(Match3Booster.bomb, 0);
      expect(corner!.first.matched, {0, 1, 6, 7});
    });

    test('rejects off-board index and finished runs without mutation', () {
      final game = fresh();
      final before = game.board;
      expect(game.useBooster(Match3Booster.bomb, -1), isNull);
      expect(game.useBooster(Match3Booster.bomb, 36), isNull);
      expect(game.board, before);
      expect(game.score, 0);

      final over = Match3Engine(
        initialBoard: _board(),
        moves: 0,
        status: Match3Status.lost,
      );
      expect(over.useBooster(Match3Booster.rowClear, 0), isNull);
      expect(over.score, 0);
    });

    test('booster can win the level', () {
      final game = Match3Engine(
        random: math.Random(2),
        initialBoard: _board(),
        score: 1190,
        moves: 5,
        status: Match3Status.playing,
      );
      game.useBooster(Match3Booster.rowClear, 0);
      expect(game.status, Match3Status.won);
    });

    test('booster with no moves left and goal missed ends the run', () {
      final game = Match3Engine(
        random: math.Random(2),
        initialBoard: _board(),
        moves: 0,
        status: Match3Status.playing,
      );
      game.useBooster(Match3Booster.bomb, 14);
      expect(game.status, Match3Status.lost);
    });
  });

  test('same SeededRandom seed + same actions replay to the same result', () {
    List<int> run() {
      final game = Match3Engine(random: SeededRandom(2026));
      for (var i = 0; i < 12; i++) {
        var done = false;
        for (var a = 0; a < game.cellCount && !done; a++) {
          for (final b in [a + 1, a + game.width]) {
            if (b < game.cellCount && game.swap(a, b) != null) {
              done = true;
              break;
            }
          }
        }
        if (i == 5) game.useBooster(Match3Booster.bomb, 14);
      }
      return [...game.board, game.score, game.moves];
    }

    expect(run(), run());
  });
}
