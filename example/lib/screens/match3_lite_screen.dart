import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

import '../game/match3_boosters.dart';

const _questId = 'match3_win_daily';
const _questRewardGems = 20;
const _achievementId = 'match3_first_win';
const _saveKey = 'match3_lite_save_v2';
const _legacySaveKey = 'match3_lite_save_v1';
const _telemetryKey = 'match3_playtest_telemetry_v1';

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
  late final InventoryService _inventory;
  late final DailyQuestService _quests;
  late final AchievementService _achievements;
  late final LocalScoreboardService _scoreboard;
  late final VersionedJsonStore<Map<String, Object?>> _save;
  late final CloudSaveProvider _cloud =
      widget.cloudProvider ?? _Match3CloudProvider();
  final _runRandom = math.Random();
  int? _selected;
  Match3Booster? _armedBooster;
  int _boosterUses = 0;
  int _runId = 0;
  int _level = 1;
  int _highestUnlockedLevel = 1;
  int _bestScore = 0;
  Map<int, int> _bestStars = {};
  bool _rewarded = false;
  bool _running = false;
  bool _animating = false;
  bool _disposed = false;
  int _animationGeneration = 0;
  Match3CascadeStep? _visibleCascadeStep;
  List<int>? _cascadeBoard;
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
    _inventory =
        InventoryService.maybe ??
        Get.put(
          InventoryService(
            storage: StorageService.to,
            itemCatalog: exampleInventoryCatalog,
            capacity: 4,
          ),
          permanent: true,
        );
    unawaited(grantStarterBoosters(_inventory));
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
    final currentStorage = StorageService.to;
    final currentRaw = currentStorage.getString(_saveKey);
    final legacyRaw = currentStorage.getString(_legacySaveKey);
    final storageKey = currentRaw == null && legacyRaw != null
        ? _legacySaveKey
        : _saveKey;
    _save = VersionedJsonStore<Map<String, Object?>>(
      storage: currentStorage,
      key: storageKey,
      schemaVersion: 3,
      toJson: (value) => value,
      fromJson: (json) => json,
      migrate: (version, json) => {
        ...json,
        'schemaVersion': 3,
        'bestStars': json['bestStars'] is Map ? json['bestStars'] : const {},
        'level': json['level'] is int ? json['level'] : 1,
        'highestUnlockedLevel': json['highestUnlockedLevel'] is int
            ? json['highestUnlockedLevel']
            : 1,
      },
    );
    final saved = _save.load();
    if (storageKey == _legacySaveKey && saved != null) {
      unawaited(_save.save(saved));
    }
    final savedLevel = saved?['level'];
    _level = savedLevel is int && savedLevel >= 1 && savedLevel <= 5
        ? savedLevel
        : 1;
    final savedUnlocked = saved?['highestUnlockedLevel'];
    _highestUnlockedLevel =
        savedUnlocked is int &&
            savedUnlocked >= _level &&
            savedUnlocked <= Match3Config.classic.levels.length
        ? savedUnlocked
        : 1;
    _bestStars = match3ReadBestStars(
      saved?['bestStars'],
      Match3Config.classic.levels.length,
    );
    final rawBest = saved?['bestScore'];
    _bestScore = rawBest is int && rawBest >= 0 ? rawBest : 0;
    final savedBoard = saved?['board'];
    var board =
        savedBoard is List &&
            savedBoard.length == Match3Config.classic.cellCount &&
            savedBoard.every(
              (tile) =>
                  tile is int &&
                  tile >= 0 &&
                  tile < Match3Config.classic.tileKinds,
            )
        ? savedBoard.cast<int>()
        : null;
    final savedStatus = Match3Status.values.where(
      (status) => status.name == saved?['status'],
    );
    final levelConfig = Match3Config.classic.levelFor(_level);
    final rawMoves = saved?['moves'];
    final hasSavedBoard = savedBoard is List;
    final moves =
        rawMoves is int &&
            rawMoves >= 0 &&
            rawMoves <= levelConfig.moves &&
            hasSavedBoard
        ? rawMoves
        : levelConfig.moves;
    final storedStatus = savedStatus.isEmpty
        ? Match3Status.ready
        : savedStatus.first;
    var rawStatus =
        moves == 0 &&
            storedStatus != Match3Status.won &&
            storedStatus != Match3Status.lost
        ? Match3Status.lost
        : (storedStatus == Match3Status.ready && moves < levelConfig.moves
              ? Match3Status.playing
              : storedStatus);
    final rawScore = saved?['score'];
    final score = rawScore is int && rawScore >= 0
        ? rawScore.clamp(0, levelConfig.scoreGoal)
        : 0;
    if (board != null) {
      try {
        Match3Engine(initialBoard: board);
      } on ArgumentError {
        board = null;
      }
    }
    var hasValidSavedBoard = board != null;
    if (board != null && !Match3Engine(initialBoard: board).hasLegalMove) {
      final shuffled = Match3Engine(random: math.Random(_runId));
      board = shuffled.board;
      if (rawStatus == Match3Status.playing &&
          moves > 0 &&
          score < levelConfig.scoreGoal) {
        rawStatus = Match3Status.ready;
        hasValidSavedBoard = false;
      }
    }
    _game =
        widget.engine ??
        Match3Engine(
          random: math.Random(_runRandom.nextInt(1 << 32)),
          initialBoard: board,
          score: score,
          moves: moves,
          level: _level,
          status: rawStatus == Match3Status.ready && moves < levelConfig.moves
              ? Match3Status.playing
              : rawStatus,
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
    'schemaVersion': 3,
    'bestStars': {for (final e in _bestStars.entries) '${e.key}': e.value},
    'level': _level,
    'highestUnlockedLevel': _highestUnlockedLevel,
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
    if (!_running || _game.isTerminal || _animating) return;
    final armed = _armedBooster;
    if (armed != null) {
      await _applyBooster(armed, index);
      return;
    }
    final selected = _selected;
    if (selected == null) {
      setState(() => _selected = index);
      return;
    }
    setState(() => _selected = null);
    final steps = _game.swap(selected, index);
    if (steps == null) {
      setState(() => _status = 'match3_invalid_swap'.tr);
      return;
    }
    _animating = true;
    final generation = ++_animationGeneration;
    if (_game.score > _bestScore) _bestScore = _game.score;
    if (_game.isTerminal && _game.status == Match3Status.won) {
      _highestUnlockedLevel = math.max(
        _highestUnlockedLevel,
        math.min(_level + 1, Match3Config.classic.levels.length),
      );
    }
    setState(() {});
    await _animateCascade(steps, generation);
    if (!mounted || generation != _animationGeneration) return;
    _game.showResolvedBoard();
    _animating = false;
    if (_game.isTerminal) await _finishRun();
    if (mounted) setState(() {});
    await _persist();
  }

  void _onBoosterSlotTap(String id) {
    if (!_running || _game.isTerminal || _animating) return;
    final booster = _boosterForSlot(id);
    if (booster == null) return;
    setState(() {
      _selected = null;
      if (_armedBooster == booster) {
        _armedBooster = null;
        _status = 'match3_booster_cancel'.tr;
      } else {
        _armedBooster = booster;
        _status = 'match3_booster_pick'.trParams({
          'booster': _boosterName(booster),
        });
      }
    });
  }

  Future<void> _onBoosterSlotEmptyTap(String id) async {
    final booster = _boosterForSlot(id);
    if (booster == null || _animating) return;
    final result = await buyBooster(
      wallet: _wallet,
      inventory: _inventory,
      booster: booster,
      purchaseId: '${booster.name}_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return;
    setState(() {
      _status = switch (result) {
        SdkSuccess() => 'match3_booster_bought'.trParams({
          'booster': _boosterName(booster),
          'price': '$match3BoosterPrice',
        }),
        SdkFailure(kind: SdkErrorKind.validation) =>
          'match3_booster_poor'.trParams({'price': '$match3BoosterPrice'}),
        SdkFailure() => 'match3_booster_failed'.tr,
      };
    });
  }

  Future<void> _applyBooster(Match3Booster booster, int index) async {
    setState(() => _armedBooster = null);
    final paid = await consumeBooster(
      inventory: _inventory,
      booster: booster,
      useId: '${_runId}_${_boosterUses++}',
    );
    if (!mounted) return;
    if (!paid) {
      setState(() => _status = 'match3_booster_failed'.tr);
      return;
    }
    final steps = _game.useBooster(booster, index);
    if (steps == null) {
      await _inventory.grant(
        lines: [
          InventoryLine(itemId: match3BoosterItemIds[booster]!, quantity: 1),
        ],
        transactionId: 'match3_refund_${_runId}_${_boosterUses - 1}',
      );
      if (mounted) setState(() => _status = 'match3_booster_failed'.tr);
      return;
    }
    _animating = true;
    final generation = ++_animationGeneration;
    if (_game.score > _bestScore) _bestScore = _game.score;
    if (_game.isTerminal && _game.status == Match3Status.won) {
      _highestUnlockedLevel = math.max(
        _highestUnlockedLevel,
        math.min(_level + 1, Match3Config.classic.levels.length),
      );
    }
    setState(
      () => _status = 'match3_booster_used'.trParams({
        'booster': _boosterName(booster),
      }),
    );
    await _animateCascade(steps, generation);
    if (!mounted || generation != _animationGeneration) return;
    _game.showResolvedBoard();
    _animating = false;
    if (_game.isTerminal) await _finishRun();
    if (mounted) setState(() {});
    await _persist();
  }

  Match3Booster? _boosterForSlot(String id) {
    for (final entry in match3BoosterItemIds.entries) {
      if (entry.value == id) return entry.key;
    }
    return null;
  }

  String _boosterName(Match3Booster booster) => switch (booster) {
    Match3Booster.rowClear => 'match3_booster_row'.tr,
    Match3Booster.columnClear => 'match3_booster_column'.tr,
    Match3Booster.bomb => 'match3_booster_bomb'.tr,
  };

  Widget _buildBoosterBar() => Obx(() {
    final snapshot = _inventory.snapshot.value;
    return BoosterSlotBar(
      key: const ValueKey('match3_booster_bar'),
      semanticLabel: 'match3_booster_bar_semantics'.tr,
      activeColor: NeonTheme.gold,
      slots: [
        for (final entry in match3BoosterItemIds.entries)
          BoosterSlot(
            id: entry.value,
            label: _boosterName(entry.key),
            iconData: switch (entry.key) {
              Match3Booster.rowClear => Icons.swap_horiz_rounded,
              Match3Booster.columnClear => Icons.swap_vert_rounded,
              Match3Booster.bomb => Icons.local_fire_department_rounded,
            },
            count: snapshot.quantityOf(entry.value),
            isLocked: !_running || _game.isTerminal,
          ),
      ],
      onSlotTap: _onBoosterSlotTap,
      onEmptySlotTap: _onBoosterSlotEmptyTap,
    );
  });

  bool get _animationValid => mounted && !_disposed;

  Future<void> _animateCascade(
    List<Match3CascadeStep> steps,
    int generation,
  ) async {
    for (final step in steps) {
      if (!_animationValid || generation != _animationGeneration) return;
      if (step.shuffled) {
        setState(() => _status = 'match3_shuffled'.tr);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        continue;
      }
      setState(() => _visibleCascadeStep = step);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!_animationValid || generation != _animationGeneration) return;
      _game.revealCascadeStep(step);
      if (_animationValid) {
        setState(() {
          _visibleCascadeStep = null;
          _cascadeBoard = step.boardAfterRefill;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 170));
      if (!_animationValid || generation != _animationGeneration) return;
      if (step.cascadeIndex > 1) {
        setState(() {
          _status = 'match3_combo'.trParams({
            'cascade': '${step.cascadeIndex}',
            'points': '${step.scoreGained}',
          });
        });
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    }
    if (_animationValid && generation == _animationGeneration) {
      setState(() {
        _status = null;
        _visibleCascadeStep = null;
        _cascadeBoard = _game.board;
      });
    }
  }

  Future<void> _recordPlaytestRun() async {
    final storage = StorageService.to;
    final raw = storage.getString(_telemetryKey);
    final report = raw == null
        ? <String, Object?>{'schemaVersion': 1, 'levels': <String, Object?>{}}
        : (jsonDecode(raw) as Map).cast<String, Object?>();
    final levels = (report['levels'] as Map).cast<String, Object?>();
    final key = '$_level';
    final previous =
        (levels[key] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{
          'plays': 0,
          'wins': 0,
          'losses': 0,
          'totalScore': 0,
          'totalMovesUsed': 0,
        };
    final won = _game.status == Match3Status.won;
    levels[key] = {
      'plays': (previous['plays'] as int) + 1,
      'wins': (previous['wins'] as int) + (won ? 1 : 0),
      'losses': (previous['losses'] as int) + (won ? 0 : 1),
      'totalScore': (previous['totalScore'] as int) + _game.score,
      'totalMovesUsed':
          (previous['totalMovesUsed'] as int) +
          (Match3Config.classic.levelFor(_level).moves - _game.moves),
    };
    await storage.setString(_telemetryKey, jsonEncode(report));
  }

  Future<void> _copyPlaytestReport() async {
    final raw = StorageService.to.getString(_telemetryKey);
    final report = raw == null
        ? <String, Object?>{'schemaVersion': 1, 'levels': <String, Object?>{}}
        : (jsonDecode(raw) as Map).cast<String, Object?>();
    final levels = (report['levels'] as Map).cast<String, Object?>();
    for (final entry in levels.entries.toList()) {
      final totals = (entry.value as Map).cast<String, Object?>();
      final plays = totals['plays'] as int;
      levels[entry.key] = {
        ...totals,
        'winRate': plays == 0 ? 0 : (totals['wins'] as int) / plays,
        'averageScore': plays == 0 ? 0 : (totals['totalScore'] as int) / plays,
        'averageMovesUsed': plays == 0
            ? 0
            : (totals['totalMovesUsed'] as int) / plays,
      };
    }
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(report)),
    );
    if (mounted) setState(() => _status = 'match3_report_copied'.tr);
  }

  Future<void> _finishRun() async {
    if (_rewarded) return;
    _running = false;
    _rewarded = true;
    await _recordPlaytestRun();
    _scoreboard.submitScore('Player', _game.score);
    if (_game.status == Match3Status.won) {
      final stars = match3StarsFor(
        movesLeft: _game.moves,
        moveLimit: _game.moveLimit,
      );
      if (stars > (_bestStars[_level] ?? 0)) _bestStars[_level] = stars;
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

  Future<void> _restart() async => _startLevel(_level);

  Future<void> _startNextLevel() async {
    if (_game.status != Match3Status.won ||
        _level >= _highestUnlockedLevel ||
        _level >= Match3Config.classic.levels.length) {
      return;
    }
    await _startLevel(_level + 1);
  }

  Future<void> _startLevel(int level) async {
    if (_running || _animating) return;
    if (level < 1 ||
        level > _highestUnlockedLevel ||
        level > Match3Config.classic.levels.length) {
      return;
    }
    if (!_energy.consumeEnergy()) {
      setState(() => _status = 'match3_no_energy'.tr);
      return;
    }
    _animationGeneration++;
    _animating = false;
    _visibleCascadeStep = null;
    _level = level;
    _game.reset(level: level);
    _selected = null;
    _armedBooster = null;
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
          final localUnlocked =
              conflict.local.value['highestUnlockedLevel'] as int? ?? 1;
          final cloudUnlocked =
              conflict.cloud.value['highestUnlockedLevel'] as int? ?? 1;
          return VersionedSyncConflictResolution.merge({
            ...conflict.local.value,
            'bestScore': math.max(localBest, cloudBest),
            'highestUnlockedLevel': math.max(localUnlocked, cloudUnlocked),
            'bestStars': {
              for (final e in match3MergeBestStars(
                match3ReadBestStars(
                  conflict.local.value['bestStars'],
                  Match3Config.classic.levels.length,
                ),
                match3ReadBestStars(
                  conflict.cloud.value['bestStars'],
                  Match3Config.classic.levels.length,
                ),
              ).entries)
                '${e.key}': e.value,
            },
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
        _bestStars = match3ReadBestStars(
          value?['bestStars'],
          Match3Config.classic.levels.length,
        );
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
                              child: AbsorbPointer(
                                absorbing: _animating,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: Match3Config.classic.cellCount,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            Match3Config.classic.width,
                                        crossAxisSpacing: 3,
                                        mainAxisSpacing: 3,
                                      ),
                                  itemBuilder: (context, index) => _tile(index),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildBoosterBar(),
                            const SizedBox(height: 12),
                            _buildActions(),
                            const SizedBox(height: 12),
                            _buildLevelSelect(),
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
      _chip('match3_level'.trParams({'level': '$_level'})),
      _chip('match3_unlocked'.trParams({'level': '$_highestUnlockedLevel'})),
      _chip('match3_score'.trParams({'score': '${_game.score}'})),
      _chip('match3_moves'.trParams({'moves': '${_game.moves}'})),
      _chip('match3_goal'.trParams({'goal': '${_game.scoreGoal}'})),
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
    final step = _visibleCascadeStep;
    final board = step?.boardBefore ?? _cascadeBoard ?? _game.board;
    final value = board[index] < 0 ? 0 : board[index];
    final matched = step?.matched.contains(index) ?? false;
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
        child: AnimatedScale(
          scale: matched ? 0.35 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: colors[value],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: matched
                    ? NeonTheme.gold
                    : (selected ? NeonTheme.ink : Colors.white70),
                width: matched || selected ? 3 : 1,
              ),
              boxShadow: NeonTheme.drop(y: 2, blur: 3),
            ),
            child: Center(
              child: Icon(
                Icons.diamond,
                color: Colors.white,
                size: matched ? 15 : (selected ? 28 : 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<LevelState> _levelStates() {
    final count = Match3Config.classic.levels.length;
    return [
      for (var level = 1; level <= count; level++)
        if (level > _highestUnlockedLevel)
          LevelState.locked
        else if (_bestStars.containsKey(level) || level < _highestUnlockedLevel)
          LevelState.completed
        else
          LevelState.unlocked,
    ];
  }

  Widget _buildLevelSelect() => Column(
    key: const ValueKey('match3_level_select'),
    children: [
      Text(
        'match3_level_select'.tr,
        style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      LevelSelectGrid(
        states: _levelStates(),
        starsEarnedByLevel: _bestStars,
        crossAxisCount: Match3Config.classic.levels.length,
        nodeSize: 52,
        spacing: 6,
        onLevelTap: _running || _animating ? null : _startLevel,
      ),
    ],
  );

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
      if (_game.status == Match3Status.won &&
          _level < _highestUnlockedLevel &&
          _level < Match3Config.classic.levels.length)
        CommonButton(
          label: 'match3_next_level'.tr,
          onTap: _startNextLevel,
          color: NeonTheme.gold,
        ),
      if (_game.isTerminal)
        CommonButton(
          label: 'match3_restart'.tr,
          onTap: _restart,
          color: NeonTheme.orange,
        ),
      CommonButton(
        label: 'match3_copy_report'.tr,
        onTap: _copyPlaytestReport,
        color: NeonTheme.cyan,
      ),
      CommonButton(
        label: 'match3_sync'.tr,
        onTap: _sync,
        color: NeonTheme.magenta,
      ),
      if (_game.hasLegalMove == false && !_game.isTerminal)
        CommonButton(
          label: 'match3_shuffle'.tr,
          onTap: () {
            _game.shuffle();
            setState(() => _status = 'match3_shuffled'.tr);
            _persist();
          },
          color: NeonTheme.purple,
        ),
    ],
  );

  @override
  void dispose() {
    _disposed = true;
    _animationGeneration++;
    super.dispose();
  }
}
