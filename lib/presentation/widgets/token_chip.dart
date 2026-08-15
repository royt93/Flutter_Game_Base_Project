import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';

/// F17: chip số dư Combo Token — cùng khuôn `CoinChip`, khác màu và icon.
///
/// Tách widget riêng thay vì thêm tham số vào `CoinChip`: hai thứ này trông
/// giống nhau nhưng đứng cạnh nhau trên cùng một action bar, nên gộp lại thành
/// một widget có cờ "loại tiền tệ" chỉ làm chỗ gọi khó đọc hơn.
class TokenChip extends StatelessWidget {
  const TokenChip(this.controller, {super.key, this.compact = false});

  final GameController controller;

  /// Bản gọn cho HUD lúc đang chơi, nơi thanh trên cùng đã chật.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('token_chip'),
      // Xem ghi chú cùng chỗ ở `coin_chip.dart` — khoảng hở phải lật theo RTL.
      margin: const EdgeInsetsDirectional.only(end: NeonTheme.s8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? NeonTheme.s8 : NeonTheme.s16,
        vertical: compact ? 4 : NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonTheme.cyan, width: 2),
        boxShadow: NeonTheme.drop(y: 3, blur: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            color: NeonTheme.cyan,
            size: compact ? 14 : 18,
          ),
          const SizedBox(width: 4),
          Obx(
            () => Text(
              fmtNum(controller.comboTokens.value),
              style: TextStyle(
                color: NeonTheme.ink,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
