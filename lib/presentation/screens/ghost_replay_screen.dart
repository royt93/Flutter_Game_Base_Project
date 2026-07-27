import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/levels.dart';
import '../../game/pop_star_game.dart';
import '../../logic/challenge_code.dart';
import '../../logic/replay.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import 'game_screen.dart';

/// I28: dán mã ghost-replay của bạn bè để tự động xem lại y hệt ván chơi
/// (bàn/nhóm nổ) qua [PopStarGame] chạy `isReplay: true` — chỉ xem, không
/// tương tác, và KHÔNG cộng bất kỳ thưởng/tiến trình thật nào (xem
/// `PopStarGame.isReplay` để biết vì sao cần chặn: [GameController] dùng ở
/// đây là 1 instance dùng-1-lần, nhưng các method thưởng của nó vẫn ghi
/// thẳng vào `StorageService.to` singleton nếu không bị chặn).
class GhostReplayScreen extends StatefulWidget {
  const GhostReplayScreen({super.key});

  @override
  State<GhostReplayScreen> createState() => _GhostReplayScreenState();
}

class _GhostReplayScreenState extends State<GhostReplayScreen> {
  static const _tapInterval = Duration(milliseconds: 450);

  final _codeCtrl = TextEditingController();
  bool _invalid = false;
  bool _finished = false;
  int _playIndex = 0;
  PopLevel? _level;
  PopStarGame? _game;
  Timer? _timer;

  /// I37: mã dán vào bắt đầu bằng [challengeCodePrefix] — hiện UI mời chơi
  /// thay vì auto-play replay như mã ghost-replay bình thường.
  ChallengeCode? _challenge;

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: NeonTheme.inkSoft),
    filled: true,
    fillColor: NeonTheme.card,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: NeonTheme.s16,
      vertical: 12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  void _load() {
    final text = _codeCtrl.text.trim();
    // I37: mã thách đấu dùng prefix rõ để phân biệt — không auto-play, chỉ
    // hiện tên người gửi + điểm cần vượt, người chơi tự bấm "Chơi ngay".
    if (text.startsWith(challengeCodePrefix)) {
      final decoded = decodeChallengeCode(text);
      _timer?.cancel();
      setState(() {
        _invalid = decoded == null;
        _finished = false;
        _level = null;
        _game = null;
        _challenge = decoded;
      });
      return;
    }
    final decoded = decodeReplay(text);
    if (decoded == null ||
        decoded.levelId < 1 ||
        decoded.levelId > kLevelCount) {
      _timer?.cancel();
      setState(() {
        _invalid = true;
        _finished = false;
        _level = null;
        _game = null;
        _challenge = null;
      });
      return;
    }
    // Instance dùng-1-lần, không đăng ký GetX — không đụng singleton thật.
    final level = kLevels[decoded.levelId - 1];
    final replayCtrl = GameController();
    replayCtrl.currentLevelRx.value = level;
    setState(() {
      _invalid = false;
      _finished = false;
      _playIndex = 0;
      _level = level;
      _game = PopStarGame(replayCtrl, seed: decoded.seed, isReplay: true);
      _challenge = null;
    });
    _startPlayback(decoded);
  }

  void _playChallenge() {
    final challenge = _challenge;
    if (challenge == null) return;
    Get.find<GameController>().startChallenge(challenge);
    Get.to(() => const GameScreen());
  }

  void _startPlayback(ReplayData data) {
    _timer?.cancel();
    _timer = Timer.periodic(_tapInterval, (t) {
      final g = _game;
      if (g == null) {
        t.cancel();
        return;
      }
      if (g.isAnimating) return; // đợi animation nhịp trước xong.
      if (_playIndex >= data.taps.length || g.replayEnded) {
        t.cancel();
        setState(() => _finished = true);
        return;
      }
      final (r, c) = data.taps[_playIndex];
      g.handleTap(g.cellCenterFor(r, c));
      _playIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final level = _level;
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'ghost_replay_title'.tr,
                color: NeonTheme.magenta,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ghost_replay_paste_label'.tr,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s8),
                      TextField(
                        controller: _codeCtrl,
                        style: TextStyle(color: NeonTheme.ink),
                        maxLines: 3,
                        minLines: 1,
                        decoration: _fieldDecoration(
                          'ghost_replay_paste_hint'.tr,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      Center(
                        child: NeonButton(
                          label: 'ghost_replay_watch_button'.tr,
                          color: NeonTheme.magenta,
                          icon: Icons.play_circle_fill_rounded,
                          onTap: _load,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      if (_invalid)
                        Text(
                          'ghost_replay_invalid_code'.tr,
                          style: const TextStyle(
                            color: NeonTheme.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_finished)
                        Text(
                          'ghost_replay_finished'.tr,
                          style: TextStyle(
                            color: NeonTheme.teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_challenge != null) ...[
                        Text(
                          'challenge_invite_title'.trParams({
                            'sender': _challenge!.senderName,
                          }),
                          style: TextStyle(
                            color: NeonTheme.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        Text(
                          'challenge_score_to_beat_label'.trParams({
                            'score': '${_challenge!.score}',
                          }),
                          style: TextStyle(color: NeonTheme.inkSoft),
                        ),
                        const SizedBox(height: NeonTheme.s16),
                        Center(
                          child: NeonButton(
                            label: 'challenge_play_button'.tr,
                            color: NeonTheme.gold,
                            icon: Icons.emoji_events_rounded,
                            onTap: _playChallenge,
                          ),
                        ),
                      ],
                      if (game != null && level != null) ...[
                        const SizedBox(height: NeonTheme.s16),
                        AspectRatio(
                          aspectRatio: level.cols / level.rows,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            // Chỉ xem: không bọc Listener/GestureDetector
                            // nào tới tay người dùng — mọi tap đến từ vòng
                            // lặp auto-playback ở [_startPlayback].
                            child: GameWidget(
                              key: ValueKey(game.seed),
                              game: game,
                              backgroundBuilder: (_) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
