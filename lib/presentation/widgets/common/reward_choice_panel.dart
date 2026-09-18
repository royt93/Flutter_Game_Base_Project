import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/reward_transaction_pipeline.dart';
import '../pressable_scale.dart';
import 'async_common_button.dart';
import 'empty_state_placeholder.dart';

/// One choosable reward option in a [RewardChoicePanel]. Immutable — the
/// panel never mutates these, only tracks *which ids* are selected/claimed
/// separately.
///
/// [lines] is purely descriptive (what this choice grants, shown to the
/// player) — the panel never calls [RewardLine]/`RewardTransactionPipeline`
/// itself; granting stays entirely the caller's job (see class doc).
class RewardChoiceOption {
  const RewardChoiceOption({
    required this.id,
    required this.label,
    this.icon,
    this.lines = const [],
    this.locked = false,
    this.lockedReason,
  });

  final String id;
  final String label;
  final IconData? icon;
  final List<RewardLine> lines;
  final bool locked;
  final String? lockedReason;
}

/// Lets a player pick one (or, with [multiSelect], several) reward from
/// [options], then confirm — this panel only ever hands back the chosen
/// **ids** via [onConfirm]; actually granting the reward is the caller's
/// job (typically a `RewardTransactionPipeline.grant()` call keyed off
/// those ids), matching this repo's "widgets don't self-grant" convention
/// (see CLAUDE.md).
///
/// [onConfirm] is wired straight into an [AsyncCommonButton], so "rapid
/// confirm doesn't double-claim" and the loading/success/error visual come
/// free from there — this panel adds no tap-guarding of its own. Once
/// [onConfirm] succeeds, the panel locks itself into a read-only "claimed"
/// view of whichever ids were just confirmed — a rebuild resets that
/// unless the caller also passes those same ids back via [claimedIds]
/// (this panel doesn't persist anything itself; [claimedIds] is how a
/// caller's own already-claimed record renders as read-only from the
/// start, e.g. after a restart).
class RewardChoicePanel extends StatefulWidget {
  RewardChoicePanel({
    super.key,
    required this.options,
    required this.onConfirm,
    this.multiSelect = false,
    this.minSelectable = 1,
    this.maxSelectable,
    this.claimedIds = const {},
    this.confirmLabel,
    this.color,
  }) : assert(
         options.map((o) => o.id).toSet().length == options.length,
         'RewardChoicePanel: duplicate option id',
       );

  final List<RewardChoiceOption> options;

  /// Called with the confirmed selection's ids. Granting the actual reward
  /// is the caller's responsibility.
  final Future<void> Function(List<String> selectedIds) onConfirm;
  final bool multiSelect;
  final int minSelectable;
  final int? maxSelectable;

  /// Ids already claimed (from the caller's own persisted record) —
  /// renders those options read-only and skips the confirm button
  /// entirely, so a returning player can't re-claim after a restart.
  final Set<String> claimedIds;
  final String? confirmLabel;
  final Color? color;

  @override
  State<RewardChoicePanel> createState() => _RewardChoicePanelState();
}

class _RewardChoicePanelState extends State<RewardChoicePanel> {
  final _selected = <String>{};
  Set<String>? _justClaimed;

  Set<String> get _effectiveClaimed =>
      widget.claimedIds.isNotEmpty ? widget.claimedIds : (_justClaimed ?? const {});

  bool get _isClaimed => _effectiveClaimed.isNotEmpty;

  void _toggle(RewardChoiceOption option) {
    if (option.locked || _isClaimed) return;
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(option.id)) {
          _selected.remove(option.id);
        } else if (widget.maxSelectable == null ||
            _selected.length < widget.maxSelectable!) {
          _selected.add(option.id);
        }
      } else {
        _selected
          ..clear()
          ..add(option.id);
      }
    });
  }

  Future<void> _handleConfirm() async {
    await widget.onConfirm(_selected.toList());
    if (mounted) setState(() => _justClaimed = Set.of(_selected));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.card_giftcard,
        message: 'No rewards to choose from.',
      );
    }
    final canConfirm =
        !_isClaimed && _selected.length >= widget.minSelectable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in widget.options) ...[
          _OptionCard(
            option: option,
            selected: _selected.contains(option.id),
            claimed: _effectiveClaimed.contains(option.id),
            color: widget.color ?? NeonTheme.cyan,
            onTap: () => _toggle(option),
          ),
          const SizedBox(height: NeonTheme.s8),
        ],
        if (!_isClaimed) ...[
          const SizedBox(height: NeonTheme.s8),
          AsyncCommonButton(
            label: widget.confirmLabel ?? 'Confirm',
            onPressed: canConfirm ? _handleConfirm : null,
          ),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.claimed,
    required this.color,
    required this.onTap,
  });

  final RewardChoiceOption option;
  final bool selected;
  final bool claimed;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = option.locked;
    final borderColor = locked
        ? NeonTheme.lockedBorder
        : (selected || claimed)
        ? color
        : NeonTheme.lockedBorder;
    final fillColor = locked ? NeonTheme.lockedFill : NeonTheme.card;
    return Semantics(
      button: true,
      enabled: !locked && !claimed,
      selected: selected || claimed,
      label: locked
          ? '${option.label}, locked${option.lockedReason != null ? ', ${option.lockedReason}' : ''}'
          : claimed
          ? '${option.label}, claimed'
          : option.label,
      child: PressableScale(
        onTap: locked || claimed ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(NeonTheme.s16),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: (selected || claimed) ? 3 : 2,
            ),
          ),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(
                  locked ? Icons.lock_rounded : option.icon,
                  color: locked ? NeonTheme.inkSoft : color,
                ),
                const SizedBox(width: NeonTheme.s8),
              ] else if (locked) ...[
                Icon(Icons.lock_rounded, color: NeonTheme.inkSoft),
                const SizedBox(width: NeonTheme.s8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: locked ? NeonTheme.inkSoft : NeonTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (option.lines.isNotEmpty)
                      Text(
                        option.lines
                            .map((l) => '+${l.amount} ${l.currency}')
                            .join(', '),
                        style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
                      ),
                    if (locked && option.lockedReason != null)
                      Text(
                        option.lockedReason!,
                        style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (claimed) ...[
                Icon(Icons.check_circle, color: color),
                const SizedBox(width: NeonTheme.s8 / 2),
                Text(
                  'Claimed',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ] else if (selected)
                Icon(Icons.check_circle_outline, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
