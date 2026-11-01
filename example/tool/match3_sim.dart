import 'dart:math' as math;

import 'package:roy_casual_kit_example/game/match3_engine.dart';

enum _Bot { random, greedy, casual, walk }

// ignore_for_file: avoid_print

void main() {
  const gamesPerLevel = 200;
  for (final bot in _Bot.values) {
    for (final level in Match3Level.levels) {
      var wins = 0;
      var totalScore = 0;
      var totalMovesRemaining = 0;
      for (var seed = 0; seed < gamesPerLevel; seed++) {
        final random = math.Random(seed + level.number * 100000);
        final game = Match3Engine(random: random, level: level.number);
        while (!game.isTerminal) {
          final moves = _legalMoves(game.board);
          final selected = switch (bot) {
            _Bot.random => moves[random.nextInt(moves.length)],
            _Bot.greedy => _bestMove(game, moves, random),
            _Bot.casual => _casualMove(game.board, moves, random),
            _Bot.walk => _walkMove(moves, random),
          };
          game.swap(selected.$1, selected.$2);
        }
        if (game.status == Match3Status.won) wins++;
        totalScore += game.score;
        totalMovesRemaining += game.moves;
      }
      final winRate = wins * 100 / gamesPerLevel;
      final averageScore = totalScore / gamesPerLevel;
      final averageMovesRemaining = totalMovesRemaining / gamesPerLevel;
      print(
        '${bot.name} L${level.number}: '
        'win=${winRate.toStringAsFixed(1)}% '
        'target=${100 - level.number * 5}% '
        'avgScore=${averageScore.toStringAsFixed(1)} '
        'avgMovesRemaining=${averageMovesRemaining.toStringAsFixed(2)}',
      );
    }
  }
}

List<(int, int)> _legalMoves(List<int> board) {
  final result = <(int, int)>[];
  for (var i = 0; i < Match3Engine.cellCount; i++) {
    if (i % Match3Engine.width < Match3Engine.width - 1) {
      _addIfLegal(board, i, i + 1, result);
    }
    if (i ~/ Match3Engine.width < Match3Engine.width - 1) {
      _addIfLegal(board, i, i + Match3Engine.width, result);
    }
  }
  return result;
}

void _addIfLegal(List<int> board, int from, int to, List<(int, int)> result) {
  final copy = List<int>.of(board);
  final tile = copy[from];
  copy[from] = copy[to];
  copy[to] = tile;
  if (_findMatches(copy).isNotEmpty) result.add((from, to));
}

// Scans from a random cell and takes the first legal swap: no size preference.
(int, int) _walkMove(List<(int, int)> moves, math.Random random) {
  final start = random.nextInt(Match3Engine.cellCount);
  return moves.firstWhere(
    (move) => move.$1 >= start,
    orElse: () => moves.first,
  );
}

(int, int) _casualMove(
  List<int> board,
  List<(int, int)> moves,
  math.Random random,
) {
  if (random.nextInt(10) < 3) return moves[random.nextInt(moves.length)];
  var bestValue = -1;
  final bestMoves = <(int, int)>[];
  for (final move in moves) {
    final swapped = List<int>.of(board);
    final tile = swapped[move.$1];
    swapped[move.$1] = swapped[move.$2];
    swapped[move.$2] = tile;
    final matches = _findMatches(swapped);
    final bottomBias = matches.fold<int>(
      0,
      (sum, index) => sum + index ~/ Match3Engine.width,
    );
    final value = matches.length * 10 + bottomBias;
    if (value > bestValue) {
      bestValue = value;
      bestMoves
        ..clear()
        ..add(move);
    } else if (value == bestValue) {
      bestMoves.add(move);
    }
  }
  return bestMoves[random.nextInt(bestMoves.length)];
}

(int, int) _bestMove(
  Match3Engine game,
  List<(int, int)> moves,
  math.Random random,
) {
  var bestGain = -1;
  final bestMoves = <(int, int)>[];
  for (final move in moves) {
    final candidate = Match3Engine(
      random: math.Random(random.nextInt(1 << 32)),
      initialBoard: game.board,
      score: game.score,
      moves: game.moves,
      status: game.status,
      level: game.level,
    );
    candidate.swap(move.$1, move.$2);
    final gain = candidate.score - game.score;
    if (gain > bestGain) {
      bestGain = gain;
      bestMoves
        ..clear()
        ..add(move);
    } else if (gain == bestGain) {
      bestMoves.add(move);
    }
  }
  return bestMoves[random.nextInt(bestMoves.length)];
}

Set<int> _findMatches(List<int> board) {
  final matches = <int>{};
  for (var y = 0; y < Match3Engine.width; y++) {
    for (var x = 0; x < Match3Engine.width; x++) {
      final index = y * Match3Engine.width + x;
      final tile = board[index];
      if (x < Match3Engine.width - 2 &&
          board[index + 1] == tile &&
          board[index + 2] == tile) {
        matches
          ..add(index)
          ..add(index + 1)
          ..add(index + 2);
      }
      if (y < Match3Engine.width - 2 &&
          board[index + Match3Engine.width] == tile &&
          board[index + 2 * Match3Engine.width] == tile) {
        matches
          ..add(index)
          ..add(index + Match3Engine.width)
          ..add(index + 2 * Match3Engine.width);
      }
    }
  }
  return matches;
}
