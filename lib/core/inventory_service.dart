import 'dart:convert';
import 'dart:math' as math;

import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/async_action_guard.dart';
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

enum ItemRarity { common, rare, epic, legendary }

/// Static catalog entry for one item id — [InventoryService] is generic
/// over whatever catalog a consumer app supplies; it has no concrete item
/// list of its own.
class ItemDefinition {
  const ItemDefinition({
    required this.id,
    this.maxStack = 1,
    this.equippable = false,
    this.rarity = ItemRarity.common,
  }) : assert(maxStack > 0, 'maxStack must be > 0');

  final String id;

  /// `1` means non-stackable (typical for equipment) — each unit occupies
  /// its own slot.
  final int maxStack;
  final bool equippable;
  final ItemRarity rarity;
}

/// One stack inside an inventory. [slotId] is a stable identity assigned
/// once at creation — it's what [InventoryService.setEquipped]/[moveSlot]
/// target, so it survives a grant/consume elsewhere in the inventory
/// changing the list's indices.
class InventorySlot {
  const InventorySlot({
    required this.slotId,
    required this.itemId,
    required this.quantity,
    this.equipped = false,
  });

  final int slotId;
  final String itemId;
  final int quantity;
  final bool equipped;

  InventorySlot copyWith({int? quantity, bool? equipped}) => InventorySlot(
    slotId: slotId,
    itemId: itemId,
    quantity: quantity ?? this.quantity,
    equipped: equipped ?? this.equipped,
  );
}

/// One `{itemId, quantity}` request line inside a [InventoryService.grant]/
/// [InventoryService.consume] call — several lines under one call apply
/// atomically (see those methods' doc).
class InventoryLine {
  const InventoryLine({required this.itemId, required this.quantity});
  final String itemId;
  final int quantity;
}

/// Immutable view of one inventory — display order is [slots]' list order.
class InventorySnapshot {
  const InventorySnapshot({required this.slots, required this.capacity});

  final List<InventorySlot> slots;
  final int capacity;

  bool get isFull => slots.length >= capacity;

  int quantityOf(String itemId) => slots
      .where((s) => s.itemId == itemId)
      .fold(0, (sum, s) => sum + s.quantity);

  List<InventorySlot> slotsFor(String itemId) =>
      slots.where((s) => s.itemId == itemId).toList();

  List<InventorySlot> get equippedSlots =>
      slots.where((s) => s.equipped).toList();
}

/// Generic slot-based inventory (consumables + equipment) — item stack
/// rules and rarity live in the caller-supplied [itemCatalog]; this service
/// only knows about slots/quantities/equipped flags and the invariants
/// around them. [grant]/[consume] follow the same idempotent-ledger pattern
/// as `EconomyWallet` (FEAT-31)/`RewardTransactionPipeline` (FEAT-42): a
/// [transactionId] repeated (even across a restart) is a no-op, and every
/// mutating call runs under [AsyncActionGuard.runExclusive] so concurrent
/// calls serialize instead of racing.
///
/// A [grant]/[consume] call taking several [InventoryLine]s applies them
/// **atomically** — if any line would fail (capacity exceeded on grant,
/// insufficient quantity on consume), none of the lines mutate the
/// inventory, not just the failing one.
class InventoryService extends GetxService {
  InventoryService({
    required this.storage,
    required Map<String, ItemDefinition> itemCatalog,
    this.capacity = 40,
    AsyncActionGuard? guard,
    String? storageKey,
    this.transactionCapacity = 200,
  }) : _catalog = itemCatalog,
       _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? 'inventory_service_v1' {
    // BUG-40: see EconomyWallet's constructor for why this can't wait for
    // onInit() alone.
    _hydrate();
    _recompute();
  }

  final StorageService storage;
  final int capacity;
  final int transactionCapacity;
  final Map<String, ItemDefinition> _catalog;
  final AsyncActionGuard _guard;
  final String _key;

  final _slots = <InventorySlot>[];
  int _nextSlotId = 1;
  final _transactions = <String>[];

  final snapshot = const InventorySnapshot(slots: [], capacity: 0).obs;

  static InventoryService? get maybe => Get.isRegistered<InventoryService>()
      ? Get.find<InventoryService>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _hydrate();
    _recompute();
  }

  void _hydrate() {
    final raw = storage.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final rawSlots = decoded['slots'];
      final loaded = <InventorySlot>[];
      if (rawSlots is List) {
        for (final entry in rawSlots) {
          if (entry is! Map) continue;
          final itemId = asStringOr(entry['itemId'], '');
          final quantity = asIntOr(entry['quantity'], 0);
          final slotId = asIntOr(entry['slotId'], 0);
          final def = _catalog[itemId];
          // Drop a malformed entry, or one referencing an item id no
          // longer in the catalog (a stale save from before an item was
          // removed/renamed) — never crash, never grant a replacement.
          if (itemId.isEmpty || quantity <= 0 || slotId <= 0 || def == null) {
            continue;
          }
          loaded.add(
            InventorySlot(
              slotId: slotId,
              itemId: itemId,
              quantity: quantity.clamp(1, def.maxStack),
              equipped: entry['equipped'] == true && def.equippable,
            ),
          );
        }
      }
      _slots
        ..clear()
        ..addAll(loaded);
      _nextSlotId = loaded.isEmpty
          ? 1
          : loaded.map((s) => s.slotId).reduce(math.max) + 1;

      final rawTransactions = decoded['transactions'];
      if (rawTransactions is List) {
        _transactions
          ..clear()
          ..addAll(rawTransactions.whereType<String>());
      }
    } catch (_) {
      _slots.clear();
      _nextSlotId = 1;
      _transactions.clear();
    }
  }

  Future<void> _persist() => storage.setString(
    _key,
    jsonEncode({
      'slots': [
        for (final s in _slots)
          {
            'slotId': s.slotId,
            'itemId': s.itemId,
            'quantity': s.quantity,
            'equipped': s.equipped,
          },
      ],
      'transactions': _transactions,
    }),
  );

  void _recompute() {
    snapshot.value = InventorySnapshot(
      slots: List.unmodifiable(_slots),
      capacity: capacity,
    );
  }

  void _appendTransaction(String transactionId) {
    _transactions.add(transactionId);
    if (_transactions.length > transactionCapacity) {
      _transactions.removeRange(0, _transactions.length - transactionCapacity);
    }
  }

  /// Grants [lines] under [transactionId]. Fills existing under-capacity
  /// stacks of the same item first, then creates new slots (up to
  /// [capacity]) for the remainder — if there isn't room for every line,
  /// the whole call is rejected and nothing is mutated (atomic).
  Future<SdkResult<InventorySnapshot>> grant({
    required List<InventoryLine> lines,
    required String transactionId,
  }) => _guard.runExclusive('inventory', () async {
    if (transactionId.isEmpty ||
        lines.isEmpty ||
        lines.any((l) => l.quantity <= 0)) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid inventory grant',
      );
    }
    if (_transactions.contains(transactionId)) {
      return SdkSuccess(snapshot.value);
    }
    for (final line in lines) {
      if (!_catalog.containsKey(line.itemId)) {
        return SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Unknown item id: ${line.itemId}',
        );
      }
    }

    var scratch = [..._slots];
    var scratchNextSlotId = _nextSlotId;
    for (final line in lines) {
      final def = _catalog[line.itemId]!;
      var remaining = line.quantity;
      for (var i = 0; i < scratch.length && remaining > 0; i++) {
        final slot = scratch[i];
        if (slot.itemId != line.itemId) continue;
        final room = def.maxStack - slot.quantity;
        if (room <= 0) continue;
        final add = math.min(room, remaining);
        scratch[i] = slot.copyWith(quantity: slot.quantity + add);
        remaining -= add;
      }
      while (remaining > 0) {
        if (scratch.length >= capacity) {
          return const SdkFailure(
            kind: SdkErrorKind.validation,
            message: 'Inventory is full',
          );
        }
        final add = math.min(def.maxStack, remaining);
        scratch.add(
          InventorySlot(
            slotId: scratchNextSlotId,
            itemId: line.itemId,
            quantity: add,
          ),
        );
        scratchNextSlotId++;
        remaining -= add;
      }
    }

    _slots
      ..clear()
      ..addAll(scratch);
    _nextSlotId = scratchNextSlotId;
    _appendTransaction(transactionId);
    await _persist();
    _recompute();
    return SdkSuccess(snapshot.value);
  });

  /// Consumes [lines] under [transactionId]. Every line's quantity is
  /// checked against the current total before any mutation — if any line
  /// is short, nothing is consumed (atomic). Consumes from the
  /// lowest-slotId stack of a matching item first; a stack emptied by this
  /// is removed.
  Future<SdkResult<InventorySnapshot>> consume({
    required List<InventoryLine> lines,
    required String transactionId,
  }) => _guard.runExclusive('inventory', () async {
    if (transactionId.isEmpty ||
        lines.isEmpty ||
        lines.any((l) => l.quantity <= 0)) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid inventory consume',
      );
    }
    if (_transactions.contains(transactionId)) {
      return SdkSuccess(snapshot.value);
    }
    final current = InventorySnapshot(slots: _slots, capacity: capacity);
    for (final line in lines) {
      if (current.quantityOf(line.itemId) < line.quantity) {
        return SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Insufficient quantity of ${line.itemId}',
        );
      }
    }

    var scratch = [..._slots]..sort((a, b) => a.slotId.compareTo(b.slotId));
    for (final line in lines) {
      var remaining = line.quantity;
      final next = <InventorySlot>[];
      for (final slot in scratch) {
        if (remaining <= 0 || slot.itemId != line.itemId) {
          next.add(slot);
          continue;
        }
        final take = math.min(slot.quantity, remaining);
        remaining -= take;
        final leftover = slot.quantity - take;
        if (leftover > 0) next.add(slot.copyWith(quantity: leftover));
      }
      scratch = next;
    }

    _slots
      ..clear()
      ..addAll(scratch);
    _appendTransaction(transactionId);
    await _persist();
    _recompute();
    return SdkSuccess(snapshot.value);
  });

  /// Sets [InventorySlot.equipped] on [slotId] — rejected if the slot
  /// doesn't exist or its item isn't [ItemDefinition.equippable]. Naturally
  /// idempotent (no transaction id needed): calling this twice with the
  /// same [equipped] value is a no-op the second time.
  Future<SdkResult<InventorySnapshot>> setEquipped({
    required int slotId,
    required bool equipped,
  }) => _guard.runExclusive('inventory', () async {
    final idx = _slots.indexWhere((s) => s.slotId == slotId);
    if (idx < 0) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Slot not found',
      );
    }
    final slot = _slots[idx];
    final def = _catalog[slot.itemId];
    if (def == null || !def.equippable) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Item is not equippable',
      );
    }
    _slots[idx] = slot.copyWith(equipped: equipped);
    await _persist();
    _recompute();
    return SdkSuccess(snapshot.value);
  });

  /// Swaps the display-order position of the slots [fromSlotId]/[toSlotId]
  /// — a pure reorder, no effect on quantity/equipped state.
  Future<SdkResult<InventorySnapshot>> moveSlot({
    required int fromSlotId,
    required int toSlotId,
  }) => _guard.runExclusive('inventory', () async {
    final fromIdx = _slots.indexWhere((s) => s.slotId == fromSlotId);
    final toIdx = _slots.indexWhere((s) => s.slotId == toSlotId);
    if (fromIdx < 0 || toIdx < 0) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Slot not found',
      );
    }
    final tmp = _slots[fromIdx];
    _slots[fromIdx] = _slots[toIdx];
    _slots[toIdx] = tmp;
    await _persist();
    _recompute();
    return SdkSuccess(snapshot.value);
  });
}
