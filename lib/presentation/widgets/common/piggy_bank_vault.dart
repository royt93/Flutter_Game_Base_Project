import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

double piggyBankFillRatio({required int amount, required int capacity}) {
  if (capacity <= 0) {
    throw ArgumentError.value(capacity, 'capacity', 'must be positive');
  }
  if (amount < 0) {
    throw ArgumentError.value(amount, 'amount', 'must be non-negative');
  }
  return (amount / capacity).clamp(0.0, 1.0);
}

bool piggyBankIsFull({required int amount, required int capacity}) =>
    piggyBankFillRatio(amount: amount, capacity: capacity) >= 1;

class PiggyBankVault extends StatefulWidget {
  const PiggyBankVault({
    super.key,
    required this.amount,
    required this.capacity,
    required this.onBreak,
    required this.onUnlock,
    this.isUnlocked = true,
    this.currencyLabel = 'coins',
    this.breakLabel = 'Break piggy bank',
    this.unlockLabel = 'Unlock',
    this.color,
    this.animateWhenFull = true,
  });

  final int amount;
  final int capacity;
  final bool isUnlocked;
  final VoidCallback? onBreak;
  final VoidCallback? onUnlock;
  final String currencyLabel;
  final String breakLabel;
  final String unlockLabel;
  final Color? color;
  final bool animateWhenFull;

  @override
  State<PiggyBankVault> createState() => _PiggyBankVaultState();
}

class _PiggyBankVaultState extends State<PiggyBankVault>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  bool get _full =>
      piggyBankIsFull(amount: widget.amount, capacity: widget.capacity);

  bool get _shouldPulse => _full && widget.isUnlocked && widget.animateWhenFull;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  void _validate() {
    piggyBankFillRatio(amount: widget.amount, capacity: widget.capacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant PiggyBankVault oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validate();
    _syncPulse();
  }

  void _syncPulse() {
    final shouldPulse = _shouldPulse && !NeonTheme.reducedMotion(context);
    if (shouldPulse) {
      final pulse = _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else if (_pulse?.isAnimating ?? false) {
      _pulse!
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = piggyBankFillRatio(
      amount: widget.amount,
      capacity: widget.capacity,
    );
    final color = widget.color ?? NeonTheme.gold;
    final shouldAnimate = _shouldPulse && !NeonTheme.reducedMotion(context);

    Widget pig = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.savings_rounded, size: 64, color: color),
        const SizedBox(height: NeonTheme.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            color: color,
            backgroundColor: NeonTheme.cardAlt,
          ),
        ),
        const SizedBox(height: NeonTheme.s8),
        Text(
          '${widget.amount} / ${widget.capacity} ${widget.currencyLabel}',
          key: const Key('piggyBankAmount'),
          style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w800),
        ),
      ],
    );

    final pulse = _pulse;
    if (shouldAnimate && pulse != null) {
      pig = AnimatedBuilder(
        key: const ValueKey('piggyBankPulse'),
        animation: pulse,
        child: pig,
        builder: (context, child) => Transform.scale(
          key: const ValueKey('piggyBankPulseTransform'),
          scale: 1 + 0.04 * pulse.value,
          child: child,
        ),
      );
    }

    return Semantics(
      label: '${widget.currencyLabel}: ${widget.amount} of ${widget.capacity}',
      value: '${(ratio * 100).round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(child: Center(child: pig)),
          const SizedBox(height: NeonTheme.s16),
          if (!widget.isUnlocked)
            CommonButton(
              key: const Key('piggyBankUnlock'),
              label: widget.unlockLabel,
              onTap: widget.onUnlock,
              color: color,
            )
          else
            CommonButton(
              key: const Key('piggyBankBreak'),
              label: widget.breakLabel,
              onTap: _full ? widget.onBreak : null,
              color: _full ? color : null,
            ),
        ],
      ),
    );
  }
}
