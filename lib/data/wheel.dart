import 'package:flutter/material.dart';

/// Loại phần thưởng trên vòng quay may mắn.
enum WheelKind { coins, hammer, moves, bomb, swap }

/// Một ô (slice) trên vòng quay.
class WheelSlice {
  final WheelKind kind;
  final int amount; // xu (coins) hoặc số booster
  final Color color;
  final IconData icon;

  const WheelSlice({
    required this.kind,
    required this.amount,
    required this.color,
    required this.icon,
  });

  bool get isCoins => kind == WheelKind.coins;

  /// Nhãn ngắn hiển thị trên ô.
  String get label => isCoins ? '$amount' : 'x$amount';
}

/// 8 ô — xen kẽ xu và booster.
const List<WheelSlice> kWheel = [
  WheelSlice(
      kind: WheelKind.coins,
      amount: 30,
      color: Color(0xFFFFFF00),
      icon: Icons.monetization_on_rounded),
  WheelSlice(
      kind: WheelKind.moves,
      amount: 1,
      color: Color(0xFF39FF14),
      icon: Icons.av_timer_rounded),
  WheelSlice(
      kind: WheelKind.coins,
      amount: 50,
      color: Color(0xFF00FFFF),
      icon: Icons.monetization_on_rounded),
  WheelSlice(
      kind: WheelKind.hammer,
      amount: 1,
      color: Color(0xFFFF6B00),
      icon: Icons.gavel_rounded),
  WheelSlice(
      kind: WheelKind.coins,
      amount: 20,
      color: Color(0xFFBC13FE),
      icon: Icons.monetization_on_rounded),
  WheelSlice(
      kind: WheelKind.bomb,
      amount: 1,
      color: Color(0xFFFF00FF),
      icon: Icons.adjust_rounded),
  WheelSlice(
      kind: WheelKind.coins,
      amount: 100,
      color: Color(0xFFFFFF00),
      icon: Icons.monetization_on_rounded),
  WheelSlice(
      kind: WheelKind.swap,
      amount: 1,
      color: Color(0xFF00FFFF),
      icon: Icons.swap_horiz_rounded),
];
