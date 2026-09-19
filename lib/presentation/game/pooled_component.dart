import 'package:flame/components.dart';

/// Mixin for a Flame [Component] that automatically returns itself to
/// whatever pool acquired it once Flame removes it from the component tree
/// (FEAT-48) — pairs `ObjectPool` (`core/utils/object_pool.dart`) with
/// Flame's own removal lifecycle so a caller never has to remember to call
/// `pool.release(this)` manually alongside `removeFromParent()`.
///
/// A component using this mixin must be released ONLY through
/// `removeFromParent()`/Flame removing it from the tree — never by calling
/// the pool's `release` directly while still attached, which would fire
/// this mixin's own release callback a second time when Flame later
/// processes the removal.
mixin PooledComponent on Component {
  void Function()? _releaseToPool;

  /// Registers the callback that returns this component to its pool —
  /// typically `() => pool.release(this)`. Call once, right after
  /// `ObjectPool.acquire()` hands this instance out and before adding it
  /// to the component tree.
  void attachToPool(void Function() releaseToPool) {
    _releaseToPool = releaseToPool;
  }

  @override
  void onRemove() {
    final release = _releaseToPool;
    _releaseToPool = null;
    release?.call();
    super.onRemove();
  }
}
