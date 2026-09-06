import 'package:get/get.dart';

/// Platform-neutral analytics/event-tracking seam — the package pulls in
/// no analytics SDK (no Firebase Analytics, no Amplitude, …); a consuming
/// app registers its own adapter via
/// `Get.put<AnalyticsProvider>(myAdapter, permanent: true)`.
abstract class AnalyticsProvider {
  void logEvent(String name, [Map<String, Object?>? params]);

  /// Null-safe accessor for call sites that may run before/without a
  /// provider registered (mirrors [CrashReporter.maybe]).
  static AnalyticsProvider? get maybe =>
      Get.isRegistered<AnalyticsProvider>() ? Get.find<AnalyticsProvider>() : null;
}

/// Default no-op implementation so a consuming app doesn't have to wire a
/// real analytics adapter immediately.
class NoopAnalyticsProvider implements AnalyticsProvider {
  @override
  void logEvent(String name, [Map<String, Object?>? params]) {}
}
