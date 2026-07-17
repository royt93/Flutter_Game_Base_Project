import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/share_helper.dart';
import '../../core/utils/friend_code.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';

/// I26 (task #18): so tài bạn bè local-only — không backend, không định
/// danh thật. Tên + tổng sao + xu được mã hoá thành 1 mã text
/// ([encodeFriendCode]/`friend_code.dart`), chia sẻ qua [shareText] có sẵn
/// (`share_helper.dart`); bạn bè dán mã nhận được vào đây để so sánh.
class FriendCompareScreen extends StatefulWidget {
  const FriendCompareScreen({super.key});

  @override
  State<FriendCompareScreen> createState() => _FriendCompareScreenState();
}

class _FriendCompareScreenState extends State<FriendCompareScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  FriendCodeData? _result;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = Get.find<GameController>().playerName.value;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _share(GameController gameCtrl) {
    gameCtrl.setPlayerName(_nameCtrl.text);
    shareText(
      'friend_share_message'.trParams({
        'name': gameCtrl.playerName.value.isEmpty
            ? 'Player'
            : gameCtrl.playerName.value,
        'stars': '${gameCtrl.totalStars.value}',
        'code': gameCtrl.myFriendCode(),
      }),
    );
  }

  void _compare() {
    final decoded = decodeFriendCode(_codeCtrl.text);
    setState(() {
      _result = decoded;
      _invalid = decoded == null;
    });
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

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'friend_compare_title'.tr,
                color: NeonTheme.teal,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'friend_your_name_label'.tr,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s8),
                      TextField(
                        controller: _nameCtrl,
                        style: TextStyle(color: NeonTheme.ink),
                        decoration: _fieldDecoration(
                          'friend_your_name_hint'.tr,
                        ),
                        onChanged: gameCtrl.setPlayerName,
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      Center(
                        child: NeonButton(
                          label: 'friend_share_code_button'.tr,
                          color: NeonTheme.teal,
                          icon: Icons.ios_share_rounded,
                          onTap: () => _share(gameCtrl),
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s24),
                      Divider(color: NeonTheme.cardAlt),
                      const SizedBox(height: NeonTheme.s16),
                      Text(
                        'friend_paste_code_label'.tr,
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
                          'friend_paste_code_hint'.tr,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      Center(
                        child: NeonButton(
                          label: 'friend_compare_button'.tr,
                          color: NeonTheme.blue,
                          icon: Icons.compare_arrows_rounded,
                          onTap: _compare,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      if (_invalid)
                        Text(
                          'friend_invalid_code'.tr,
                          style: const TextStyle(
                            color: NeonTheme.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_result != null)
                        _ResultCard(
                          result: _result!,
                          myStars: gameCtrl.totalStars.value,
                        ),
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

class _ResultCard extends StatelessWidget {
  final FriendCodeData result;
  final int myStars;

  const _ResultCard({required this.result, required this.myStars});

  @override
  Widget build(BuildContext context) {
    final diff = myStars - result.totalStars;
    final String message;
    final Color color;
    if (diff > 0) {
      message = 'friend_result_ahead'.trParams({
        'name': result.name,
        'n': '$diff',
      });
      color = NeonTheme.lime;
    } else if (diff < 0) {
      message = 'friend_result_behind'.trParams({
        'name': result.name,
        'n': '${-diff}',
      });
      color = NeonTheme.orange;
    } else {
      message = 'friend_result_tie'.trParams({'name': result.name});
      color = NeonTheme.gold;
    }
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: NeonTheme.glow(color),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: NeonTheme.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
