import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _entries = [
  CommunityLeaderboardEntry(
    id: 'player_a',
    rank: 1,
    playerName: 'Aster',
    score: '12,450',
    zone: TierZone.promotion,
    tier: LeaderboardTier.gold,
  ),
  CommunityLeaderboardEntry(
    id: 'player_b',
    rank: 2,
    playerName: 'Beryl',
    score: '10,200',
    zone: TierZone.safe,
    tier: LeaderboardTier.silver,
    isCurrentPlayer: true,
  ),
  CommunityLeaderboardEntry(
    id: 'player_c',
    rank: 3,
    playerName: 'Cinder',
    score: '8,900',
    zone: TierZone.demotion,
    tier: LeaderboardTier.bronze,
  ),
];

Widget _subject({
  List<CommunityLeaderboardEntry> entries = _entries,
  ValueChanged<String>? onPlayerTap,
  VoidCallback? onRefresh,
  bool isLoading = false,
  String? errorMessage,
  Future<void> Function()? onRetry,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: CommunityLeaderboardCard(
          entries: entries,
          onPlayerTap: onPlayerTap,
          onRefresh: onRefresh,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRetry: onRetry,
        ),
      ),
    ),
  ),
);

void main() {
  group('CommunityLeaderboardCard validation', () {
    test('rejects invalid ids, names, scores, ranks and duplicate ids', () {
      CommunityLeaderboardEntry row({
        String id = 'id',
        String name = 'Name',
        String score = '10',
        int rank = 1,
      }) => CommunityLeaderboardEntry(
        id: id,
        rank: rank,
        playerName: name,
        score: score,
      );

      void invalid(List<CommunityLeaderboardEntry> entries) => expect(
        () => CommunityLeaderboardCard(entries: entries),
        throwsArgumentError,
      );

      invalid([row(id: ' ')]);
      invalid([row(name: ' ')]);
      invalid([row(score: ' ')]);
      invalid([row(rank: 0)]);
      invalid([row(), row()]);
    });
  });

  group('CommunityLeaderboardCard UI', () {
    testWidgets('preserves caller order and highlights current player', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(_subject(onPlayerTap: (id) => tapped = id));

      expect(find.text('Aster'), findsOneWidget);
      expect(find.text('Beryl'), findsOneWidget);
      expect(find.text('Cinder'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('communityLeaderboard_player_a')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('communityLeaderboard_player_b')),
              )
              .dy,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('communityLeaderboard_player_b')),
      );
      expect(tapped, 'player_b');
    });

    testWidgets('refresh calls caller and loading replaces rows', (
      tester,
    ) async {
      var refreshes = 0;
      await tester.pumpWidget(_subject(onRefresh: () => refreshes++));
      await tester.tap(
        find.byKey(const ValueKey('communityLeaderboardRefresh')),
      );
      expect(refreshes, 1);

      await tester.pumpWidget(_subject(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Aster'), findsNothing);
    });

    testWidgets('error and retry state', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _subject(errorMessage: 'Offline', onRetry: () async => retried = true),
      );
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Aster'), findsNothing);
      await tester.tap(find.byType(AsyncCommonButton));
      expect(retried, isTrue);
    });

    testWidgets('empty state and semantics', (tester) async {
      await tester.pumpWidget(_subject(entries: const []));
      expect(find.text('No leaderboard entries yet.'), findsOneWidget);

      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('communityLeaderboardSemantics')),
      );
      expect(semantics.properties.label, 'Community Leaderboard. 3 players.');
    });

    testWidgets('no overflow at text scale 2.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(_subject());
      expect(tester.takeException(), isNull);
    });
  });
}
