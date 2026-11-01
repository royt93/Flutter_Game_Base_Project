import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

import '../game/match3_engine.dart';

const _questId = 'match3_win_daily';
const _questRewardGems = 20;
const _achievementId = 'match3_first_win';
const _saveKey = 'match3_lite_save_v1';

class _Match3CloudProvider implements CloudSaveProvider {
  Map<String, Object?>? data;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> upload(Map<String, Object?> data) async {
    this.data = Map.of(data);
  }

  @override
  Future<Map<String, Object?>?> download() async =>
      data == null ? null : Map.of(data!);
}

class Match3LiteScreen extends StatefulWidget {
  const Match3LiteScreen({super.key, this.cloudProvider, this.engine});

  final CloudSaveProvider? cloudProvider;
  final Match3Engine? engine;

  @override
  State<Match3LiteScreen> createState() => _Match3LiteScreenState();
}

class _Match3LiteScreenState extends State<Match3LiteScreen> {
  late final Match3Engine _game;
  late final EnergyService _energy;
  late final EconomyWallet _wallet;
  late final DailyQuestService _quests;
  late final AchievementService _achievements;
  late final LocalScoreboardService _scoreboard;
  late final VersionedJsonStore<Map<String, Object?>> _save;
  late final CloudSaveProvider _cloud =
      widget.cloudProvider ?? _Match3CloudProvider();
  final _runRandom = math.Random();
  int? _selected;
  int _runId = 0;
  int _bestScore = 0;
  bool _rewarded = false;
  bool _running = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _energy =
        EnergyService.maybe ??
        Get.put(EnergyService(maxEnergy: 5), permanent: true);
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _quests =
        DailyQuestService.maybe ??
        Get.put(DailyQuestService(), permanent: true);
    _quests.register(_questId, 3);
    _achievements =
        AchievementService.maybe ??
        Get.put(AchievementService(), permanent: true);
    _achievements.register(_achievementId, 1);
    _scoreboard =
        LocalScoreboardService.maybe ??
        Get.put(LocalScoreboardService(capacity: 20), permanent: true);
    _save = VersionedJsonStore<Map<String, Object?>>(
      storage: StorageService.to,
      key: _saveKey,
      schemaVersion: 1,
      toJson: (value) => value,
      fromJson: (json) => json,
      migrate: (version, json) => json,
    );
    final saved = _save.load();
    final rawBest = saved?['bestScore'];
    _bestScore = rawBest is int && rawBest >= 0 ? rawBest : 0;
    final savedBoard = saved?['board'];
    var board =
        savedBoard is List &&
            savedBoard.length == Match3Engine.cellCount &&
            savedBoard.every(
              (tile) =>
                  tile is int && tile >= 0 && tile < Match3Engine.tileKinds,
            )
        ? savedBoard.cast<int>()
        : null;
    final savedStatus = Match3Status.values.where(
      (status) => status.name == saved?['status'],
    );
    final rawMoves = saved?['moves'];
    final moves =
        rawMoves is int && rawMoves >= 0 && rawMoves <= Match3Engine.maxMoves
        ? rawMoves
        : Match3Engine.maxMoves;
    final storedStatus = savedStatus.isEmpty
        ? Match3Status.ready
        : savedStatus.first;
    var rawStatus =
        moves == 0 &&
            storedStatus != Match3Status.won &&
            storedStatus != Match3Status.lost
        ? Match3Status.lost
        : (storedStatus == Match3Status.ready && moves < Match3Engine.maxMoves
              ? Match3Status.playing
              : storedStatus);
    final rawScore = saved?['score'];
    final score = rawScore is int && rawScore >= 0
        ? rawScore.clamp(0, Match3Engine.scoreGoal)
        : 0;
    if (board != null) {
      try {
        Match3Engine(initialBoard: board);
      } on ArgumentError {
        board = null;
      }
    }
    var hasValidSavedBoard = board != null;
    if (board != null &&
        rawStatus == Match3Status.playing &&
        moves > 0 &&
        score < Match3Engine.scoreGoal &&
        !Match3Engine(initialBoard: board).hasLegalMove) {
      final shuffled = Match3Engine(random: math.Random(_runId));
      board = shuffled.board;
      hasValidSavedBoard = false;
    }
    _game =
        widget.engine ??
        Match3Engine(
          random: math.Random(_runRandom.nextInt(1 << 32)),
          initialBoard: board,
          score: score,
          moves: moves,
          status: rawStatus,
        );
    final runId = saved?['runId'];
    _runId = runId is int && runId >= 0
        ? runId
        : DateTime.now().microsecondsSinceEpoch;
    _rewarded = saved?['rewarded'] == true || _game.isTerminal;
    _running =
        hasValidSavedBoard &&
        saved?['runActive'] == true &&
        !_game.isTerminal &&
        !_rewarded;
  }

  Map<String, Object?> _saveData() => {
    'bestScore': _bestScore,
    'board': _game.board,
    'score': _game.score,
    'moves': _game.moves,
    'status': _game.status.name,
    'runActive': _running,
    'rewarded': _rewarded,
    'runId': _runId,
  };

  Future<void> _persist() => _save.save(_saveData());

  Future<void> _startRun() async {
    if (_running || _game.isTerminal) return;
    if (_game.status == Match3Status.ready) {
      if (!_energy.consumeEnergy()) {
        setState(() => _status = 'match3_no_energy'.tr);
        return;
      }
    }
    setState(() {
      _running = true;
      _status = null;
    });
    await _persist();
  }

  Future<void> _swap(int index) async {
    if (!_running || _game.isTerminal) return;
    final selected = _selected;
    if (selected == null) {
      setState(() => _selected = index);
      return;
    }
    setState(() => _selected = null);
    if (!_game.swap(selected, index)) return;
    if (_game.score > _bestScore) _bestScore = _game.score;
    if (_game.isTerminal) await _finishRun();
    if (mounted) setState(() {});
    await _persist();
  }

  Future<void> _finishRun() async {
    if (_rewarded) return;
    _running = false;
    _rewarded = true;
    _scoreboard.submitScore('Player', _game.score);
    if (_game.status == Match3Status.won) {
      final questWasClaimed = _quests.isClaimed(_questId);
      _quests.incrementProgress(_questId, 1);
      _achievements.incrementProgress(_achievementId, 1);
      final questReadyToClaim =
          _quests.isCompleted(_questId) && !questWasClaimed;
      final rewards = <Future<SdkResult<int>>>[
        _wallet.earn(
          currency: 'coins',
          amount: 25,
          transactionId: 'match3_win_$_runId',
        ),
      ];
      if (questReadyToClaim) {
        rewards.add(
          _wallet.earn(
            currency: 'gems',
            amount: _questRewardGems,
            transactionId: 'match3_quest_${_questId}_${todayEpochDayClamped()}',
          ),
        );
      }
      final results = await Future.wait(rewards);
      final coinRewardSucceeded = results.first.isSuccess;
      final questRewardSucceeded =
          !questReadyToClaim || (results.length > 1 && results[1].isSuccess);
      if (questReadyToClaim && questRewardSucceeded) {
        _quests.claim(_questId);
      }
      _status = questReadyToClaim && questRewardSucceeded
          ? 'match3_win_quest'.trParams({
              'coins': '25',
              'gems': '$_questRewardGems',
            })
          : (coinRewardSucceeded ? 'match3_win'.tr : 'match3_reward_failed'.tr);
    } else {
      _status = 'match3_moves_over'.tr;
    }
    if (mounted) setState(() {});
  }

  Future<void> _restart() async {
    if (_running || !_game.isTerminal) return;
    if (!_energy.consumeEnergy()) {
      setState(() => _status = 'match3_no_energy'.tr);
      return;
    }
    _game.reset();
    _selected = null;
    _rewarded = false;
    _running = true;
    _runId = DateTime.now().microsecondsSinceEpoch;
    setState(() => _status = null);
    await _persist();
  }

  Future<void> _sync() async {
    try {
      await _save.save(_saveData());
      if (await _cloud.download() == null) {
        await _cloud.upload(_saveData());
      }
      final result = await _save.syncWithResult(
        _cloud,
        onConflict: (conflict) {
          final localBest = conflict.local.value['bestScore'] as int? ?? 0;
          final cloudBest = conflict.cloud.value['bestScore'] as int? ?? 0;
          return VersionedSyncConflictResolution.merge({
            ...conflict.local.value,
            'bestScore': math.max(localBest, cloudBest),
          });
        },
      );
      if (result case SdkFailure<void>()) {
        if (mounted) setState(() => _status = 'match3_sync_failed'.tr);
        return;
      }
      final value = _save.load();
      if (!mounted) return;
      setState(() {
        _bestScore = value?['bestScore'] is int
            ? value!['bestScore'] as int
            : _bestScore;
        _status = 'match3_sync_done'.tr;
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'match3_sync_failed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: Column(
          children: [
            NeonAppBar(title: 'match3_title'.tr, onBack: Get.back),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = math.min(
                    constraints.maxWidth - 24,
                    constraints.maxHeight * 0.64,
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            _buildHud(),
                            const SizedBox(height: 12),
                            SizedBox.square(
                              dimension: side,
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: Match3Engine.cellCount,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: Match3Engine.width,
                                      crossAxisSpacing: 3,
                                      mainAxisSpacing: 3,
                                    ),
                                itemBuilder: (context, index) => _tile(index),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActions(),
                            if (_status != null) ...[
                              const SizedBox(height: 8),
                              Semantics(
                                liveRegion: true,
                                child: Text(_status!.tr),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'match3_achievement_progress'.trParams({
                                'value':
                                    '${_achievements.progressOf(_achievementId)}',
                              }),
                            ),
                            Text(
                              'match3_quest_progress'.trParams({
                                'value': '${_quests.progressOf(_questId)}',
                              }),
                            ),
                            Text(
                              'match3_leaderboard_count'.trParams({
                                'count': '${_scoreboard.topN(20).length}',
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildHud() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      _chip('match3_score'.trParams({'score': '${_game.score}'})),
      _chip('match3_moves'.trParams({'moves': '${_game.moves}'})),
      _chip('match3_goal'.trParams({'goal': '${Match3Engine.scoreGoal}'})),
      _chip('match3_best'.trParams({'score': '$_bestScore'})),
      _chip('match3_energy'.trParams({'energy': '${_energy.currentEnergy}'})),
      _chip(
        'match3_coins'.trParams({'coins': '${_wallet.balanceOf('coins')}'}),
      ),
    ],
  );

  Widget _chip(String text) => PanelCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(
      text,
      style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w800),
    ),
  );

  Widget _tile(int index) {
    final value = _game.board[index];
    const colors = [
      Color(0xffef5350),
      Color(0xffffca28),
      Color(0xff66bb6a),
      Color(0xff42a5f5),
      Color(0xffab47bc),
    ];
    final selected = _selected == index;
    return Semantics(
      button: true,
      label: 'match3_tile_semantics'.trParams({
        'row': '${index ~/ 6 + 1}',
        'column': '${index % 6 + 1}',
      }),
      child: SquashStretch(
        key: ValueKey('match3_tile_$index'),
        onTap: () => _swap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: colors[value],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? NeonTheme.ink : Colors.white70,
              width: selected ? 3 : 1,
            ),
            boxShadow: NeonTheme.drop(y: 2, blur: 3),
          ),
          child: Center(
            child: Icon(
              Icons.diamond,
              color: Colors.white,
              size: selected ? 28 : 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      if (!_running && !_game.isTerminal)
        CommonButton(
          label: 'match3_start'.tr,
          onTap: _startRun,
          color: NeonTheme.cyan,
        ),
      if (_game.isTerminal)
        CommonButton(
          label: 'match3_restart'.tr,
          onTap: _restart,
          color: NeonTheme.orange,
        ),
      CommonButton(
        label: 'match3_sync'.tr,
        onTap: _sync,
        color: NeonTheme.magenta,
      ),
    ],
  );

  @override
  void dispose() {
    super.dispose();
  }
}
