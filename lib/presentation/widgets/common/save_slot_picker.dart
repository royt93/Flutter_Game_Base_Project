import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/save_slot_manager.dart';
import '../../../core/utils/format.dart';
import 'common_button.dart';
import 'confirm_dialog.dart';
import 'empty_state_placeholder.dart';
import 'retry_error_state.dart';

/// Presentation-only UI picker for browsing, selecting, creating, and deleting
/// save slots (FEAT-143).
///
/// Designed to compose directly with [SaveSlotManager.listSlots] and
/// [SaveSlotManager.activeSlotId], while leaving actual storage transactions
/// to the caller.
class SaveSlotPicker extends StatelessWidget {
  SaveSlotPicker({
    super.key,
    required this.slots,
    this.activeSlotId,
    required this.onSelect,
    this.onCreate,
    this.onDelete,
    this.maxSlots,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.title = 'Select Save Slot',
    this.createLabel = 'Create New Slot',
    this.emptyMessage = 'No save slots yet',
    this.semanticLabel,
  }) {
    if (maxSlots != null && maxSlots! <= 0) {
      throw ArgumentError.value(maxSlots, 'maxSlots', 'must be greater than 0');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (createLabel.trim().isEmpty) {
      throw ArgumentError.value(
        createLabel,
        'createLabel',
        'must not be empty',
      );
    }
    final seenIds = <String>{};
    for (final slot in slots) {
      if (slot.id.trim().isEmpty) {
        throw ArgumentError.value(slot.id, 'slot.id', 'must not be empty');
      }
      if (slot.displayName.trim().isEmpty) {
        throw ArgumentError.value(
          slot.displayName,
          'slot.displayName',
          'must not be empty',
        );
      }
      if (slot.createdAtMs < 0) {
        throw ArgumentError.value(
          slot.createdAtMs,
          'slot.createdAtMs',
          'must be non-negative',
        );
      }
      if (slot.lastPlayedAtMs < 0) {
        throw ArgumentError.value(
          slot.lastPlayedAtMs,
          'slot.lastPlayedAtMs',
          'must be non-negative',
        );
      }
      if (!seenIds.add(slot.id)) {
        throw ArgumentError.value(
          slot.id,
          'slots',
          'duplicate slot id: ${slot.id}',
        );
      }
    }
  }

  final List<SaveSlotMeta> slots;
  final String? activeSlotId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onDelete;
  final int? maxSlots;
  final bool loading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final String title;
  final String createLabel;
  final String emptyMessage;
  final String? semanticLabel;

  bool get _canCreate =>
      onCreate != null && (maxSlots == null || slots.length < maxSlots!);

  @override
  Widget build(BuildContext context) {
    final effectiveSemantics =
        semanticLabel ??
        '$title. ${slots.length} slots available. Active: ${activeSlotId ?? "None"}.';

    return Semantics(
      key: const ValueKey('saveSlotPickerSemantics'),
      container: true,
      label: effectiveSemantics,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: NeonTheme.cyan.withValues(alpha: 0.35),
            width: 2,
          ),
          boxShadow: NeonTheme.drop(y: 8, blur: 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.save_rounded, color: NeonTheme.cyan, size: 26),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: NeonTheme.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (maxSlots != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NeonTheme.cardAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: NeonTheme.inkSoft.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${slots.length}/$maxSlots',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NeonTheme.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NeonTheme.s16),
            Flexible(child: _buildBody(context)),
            if (onCreate != null) ...[
              const SizedBox(height: NeonTheme.s16),
              CommonButton(
                key: const ValueKey('saveSlotCreateBtn'),
                label: createLabel,
                variant: CommonButtonVariant.primary,
                color: NeonTheme.cyan,
                onTap: _canCreate ? onCreate : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(NeonTheme.s24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (errorMessage != null) {
      return RetryErrorState(
        key: const ValueKey('saveSlotPickerError'),
        message: errorMessage!,
        onRetry: onRetry,
      );
    }
    if (slots.isEmpty) {
      return EmptyStatePlaceholder(
        key: const ValueKey('saveSlotPickerEmpty'),
        icon: Icons.folder_open_rounded,
        message: emptyMessage,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: slots.length,
      separatorBuilder: (_, _) => const SizedBox(height: NeonTheme.s8),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isActive = slot.id == activeSlotId;
        return _buildSlotRow(context, slot, isActive);
      },
    );
  }

  Widget _buildSlotRow(BuildContext context, SaveSlotMeta slot, bool isActive) {
    final playedDuration = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(slot.lastPlayedAtMs),
    );
    final playedLabel = playedDuration.inMinutes < 1
        ? 'Just now'
        : '${fmtDurDays(playedDuration)} ago';

    return Container(
      key: ValueKey('saveSlotRow_${slot.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? NeonTheme.cyan.withValues(alpha: 0.12)
            : NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? NeonTheme.cyan
              : NeonTheme.inkSoft.withValues(alpha: 0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.stars_rounded : Icons.folder_rounded,
            color: isActive ? NeonTheme.gold : NeonTheme.cyan,
            size: 26,
          ),
          const SizedBox(width: NeonTheme.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        slot.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: NeonTheme.ink,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: NeonTheme.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: NeonTheme.cyan,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Played: $playedLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NeonTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          if (!isActive)
            CommonButton(
              key: ValueKey('saveSlotSelectBtn_${slot.id}'),
              label: 'Select',
              width: 90,
              variant: CommonButtonVariant.secondary,
              color: NeonTheme.cyan,
              onTap: () => onSelect(slot.id),
            ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              key: ValueKey('saveSlotDeleteBtn_${slot.id}'),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: NeonTheme.red,
                size: 22,
              ),
              tooltip: 'Delete Slot',
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete Save Slot?',
                  message:
                      'Are you sure you want to delete "${slot.displayName}"? All progress in this slot will be permanently lost.',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                  color: NeonTheme.red,
                  icon: Icons.delete_forever_rounded,
                );
                if (confirmed) {
                  onDelete!(slot.id);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
