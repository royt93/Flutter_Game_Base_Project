import 'package:get/get.dart';

/// Platform-neutral crash/error reporting seam — `dlog()` is debug-only
/// (tree-shaken out of release builds), so without this, every runtime
/// error in production is silent. The package itself pulls in no crash
/// SDK; a consuming app registers its own adapter (Crashlytics, Sentry, …)
/// via `Get.put<CrashReporter>(myAdapter, permanent: true)`.
abstract class CrashReporter {
  void recordError(Object error, StackTrace stack, {String? reason});

  /// Null-safe accessor for call sites that may run before/without a
  /// reporter registered (mirrors [AudioManager.maybe]).
  static CrashReporter? get maybe =>
      Get.isRegistered<CrashReporter>() ? Get.find<CrashReporter>() : null;
}
