/// Generic acquire/release object pool (FEAT-48) — reuses instances of [T]
/// (a Flame particle/projectile component, or any other allocation-heavy
/// object) instead of letting a hot gameplay loop allocate and immediately
/// discard one every frame.
///
/// Identity, not equality, decides which object is "active": [release]
/// checks that the exact instance passed in is the one this pool currently
/// considers acquired, so a subclass of [T] overriding `==`/`hashCode`
/// doesn't confuse double-release detection.
class ObjectPool<T> {
  ObjectPool({
    required T Function() create,
    void Function(T item)? reset,
    void Function(T item)? dispose,
    this.maxCapacity = 200,
  }) : _create = create,
       _reset = reset,
       _dispose = dispose,
       assert(maxCapacity > 0, 'maxCapacity must be greater than 0');

  final T Function() _create;
  final void Function(T item)? _reset;
  final void Function(T item)? _dispose;

  /// Upper bound on `freeCount + activeCount` this pool ever holds onto —
  /// [acquire] may still create past it (a pool never refuses to hand out
  /// an object), but [release] disposes rather than retains once at the
  /// cap, so a burst that briefly exceeds it doesn't permanently bloat the
  /// pool's resting size.
  final int maxCapacity;

  final _free = <T>[];
  final _active = <T>{};

  int _totalCreated = 0;
  int _peakActive = 0;

  int get freeCount => _free.length;
  int get activeCount => _active.length;

  /// Total number of objects [create] has ever produced — the metric a
  /// benchmark compares against an unpooled baseline to show reuse working.
  int get totalCreated => _totalCreated;

  /// Highest [activeCount] this pool has ever reached.
  int get peakActive => _peakActive;

  T _createNew() {
    _totalCreated++;
    return _create();
  }

  /// Creates up to [count] objects ahead of time into the free list, so the
  /// first burst of real [acquire] calls doesn't pay allocation cost.
  /// Capped at [maxCapacity] — never over-fills the pool's resting size.
  void prewarm(int count) {
    final room = maxCapacity - (_free.length + _active.length);
    final toCreate = count < room ? count : room;
    for (var i = 0; i < toCreate; i++) {
      _free.add(_createNew());
    }
  }

  /// Hands out a reusable [T] — an existing free one if available,
  /// otherwise a freshly [create]d one. Always succeeds; [maxCapacity]
  /// bounds what [release] retains, not what [acquire] can hand out.
  T acquire() {
    final item = _free.isNotEmpty ? _free.removeLast() : _createNew();
    _active.add(item);
    if (_active.length > _peakActive) _peakActive = _active.length;
    return item;
  }

  /// Returns [item] to the pool — [reset] clears its mutable gameplay
  /// state, then it either rejoins the free list or, if
  /// `freeCount + activeCount` is already at [maxCapacity], is
  /// [dispose]d instead of retained.
  ///
  /// Throws [StateError] if [item] isn't currently acquired from this pool
  /// — either a double-release of something already returned, or an object
  /// this pool never handed out.
  void release(T item) {
    if (!_active.remove(item)) {
      throw StateError(
        'release() called with an object not currently active in this '
        'pool — either a double-release or an object this pool never '
        'acquired out',
      );
    }
    _reset?.call(item);
    if (_free.length + _active.length < maxCapacity) {
      _free.add(item);
    } else {
      _dispose?.call(item);
    }
  }

  /// Disposes every object this pool currently holds — free and active
  /// alike — and empties it. For tearing the pool down entirely (e.g. a
  /// game session ending), not for routine reuse.
  void disposeAll() {
    for (final item in _free) {
      _dispose?.call(item);
    }
    _free.clear();
    for (final item in _active) {
      _dispose?.call(item);
    }
    _active.clear();
  }
}
