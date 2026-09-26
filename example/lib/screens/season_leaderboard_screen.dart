import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

class SeasonLeaderboardScreen extends StatefulWidget {
  const SeasonLeaderboardScreen({super.key});

  @override
  State<SeasonLeaderboardScreen> createState() =>
      _SeasonLeaderboardScreenState();
}

class _SeasonLeaderboardScreenState extends State<SeasonLeaderboardScreen> {
  static const _seasonEventId = 'season_spring_pass';
  static const _seasonLength = Duration(days: 7);
  static const _seasonCooldown = Duration(days: 1);

  late final SeasonEventService _season;
  late final LocalScoreboardService _scoreboard;
  final _haptics = HapticChoreographer();

  int _seasonPoints = 0;
  String _status = 'Compete in the active season and climb the leaderboard!';

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _season =
        SeasonEventService.maybe ??
        Get.put(SeasonEventService(), permanent: true);
    _scoreboard =
        LocalScoreboardService.maybe ??
        Get.put(LocalScoreboardService(capacity: 20), permanent: true);

    _seasonPoints = StorageService.to.getInt('demo_season_points', def: 0);
  }

  Future<void> _addSeasonPoints() async {
    final next = _seasonPoints + 25;
    await StorageService.to.setInt('demo_season_points', next);
    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() {
      _seasonPoints = next;
      _status = 'Earned +25 Season Points! Total: $next pts.';
    });
  }

  Future<void> _submitScore(int score) async {
    _scoreboard.submitScore('Hero Player', score);
    _haptics.play(HapticPattern.combo);
    if (!mounted) return;
    setState(() {
      _status = 'Submitted high score: $score!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final window = _season.currentWindow(
      _seasonEventId,
      length: _seasonLength,
      cooldown: _seasonCooldown,
    );
    final topScores = _scoreboard.topN(5);

    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'season_leaderboard'.tr, onBack: Get.back),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s8,
                ),
                child: PanelCard(
                  child: Text(_status, style: TextStyle(color: NeonTheme.ink)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeonTheme.s16,
                    vertical: NeonTheme.s8,
                  ),
                  children: [
                    // Season Pass status card
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Season 1: Neon Dawn',
                                style: TextStyle(
                                  color: NeonTheme.ink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              CountdownChip(
                                target: window.end,
                                color:
                                    window.isActive
                                        ? NeonTheme.lime
                                        : NeonTheme.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            window.isActive
                              ? 'Active Season • Earn points to unlock battle pass tiers.'
                              : 'Season Cooldown • Next season starting soon.',
                            style: TextStyle(color: NeonTheme.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Season Points: $_seasonPoints',
                                style: TextStyle(
                                  color: NeonTheme.cyan,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Tier: ${_seasonPoints ~/ 50 + 1}',
                                style: TextStyle(
                                  color: NeonTheme.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CommonButton(
                            label: 'Earn +25 Season Points',
                            onTap: window.isActive ? _addSeasonPoints : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    // Leaderboard section
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Local Leaderboard',
                                style: TextStyle(
                                  color: NeonTheme.ink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              CommonButton(
                                width: 140,
                                label: 'Submit +500',
                                variant: CommonButtonVariant.secondary,
                                onTap: () => _submitScore(500 + _seasonPoints * 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (topScores.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: NeonTheme.s16,
                              ),
                              child: Text(
                                'No scores submitted yet. Tap "Submit +500" above!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: NeonTheme.inkSoft),
                              ),
                            )
                          else
                            LeaderboardList(
                              entries: topScores,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
