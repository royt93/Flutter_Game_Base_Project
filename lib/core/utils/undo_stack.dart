/// A bounded undo/redo history of immutable state snapshots (FEAT-216).
///
/// Push the state you want to be able to return to after every change;
/// [undo] steps back to the previous snapshot and [redo] forward again. A
/// [push] after an [undo] drops the redo branch, as every editor does. When
/// more than [capacity] snapshots exist the OLDEST is dropped.
///
/// Snapshot-based: the stack keeps the exact objects you pass in and never
/// clones them, so [T] must be immutable (or copied by the caller) or a later
/// mutation would rewrite history. Pure Dart, no Flutter.
class UndoStack<T> {
  UndoStack({required this.capacity}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be > 0');
    }
  }

  /// Most snapshots kept, the current one included.
  final int capacity;

  final List<T> _items = [];
  int _index = -1;

  /// Snapshots held, current one included (0 when empty).
  int get length => _items.length;

  /// The snapshot undo/redo currently points at, or `null` when empty.
  T? get current => _index < 0 ? null : _items[_index];

  bool get canUndo => _index > 0;

  bool get canRedo => _index >= 0 && _index < _items.length - 1;

  /// Records [state] as the new current snapshot, dropping any redo branch and
  /// the oldest snapshot when [capacity] is exceeded.
  void push(T state) {
    if (_index < _items.length - 1) {
      _items.removeRange(_index + 1, _items.length);
    }
    _items.add(state);
    if (_items.length > capacity) _items.removeAt(0);
    _index = _items.length - 1;
  }

  /// Steps back and returns the snapshot now current, or `null` (changing
  /// nothing) when there is nothing to undo.
  T? undo() {
    if (!canUndo) return null;
    _index--;
    return _items[_index];
  }

  /// Steps forward and returns the snapshot now current, or `null` (changing
  /// nothing) when there is nothing to redo.
  T? redo() {
    if (!canRedo) return null;
    _index++;
    return _items[_index];
  }

  /// Forgets every snapshot.
  void clear() {
    _items.clear();
    _index = -1;
  }
}
