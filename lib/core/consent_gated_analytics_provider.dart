import 'analytics_provider.dart';
import 'consent_state_service.dart';

/// Decorator over a real [AnalyticsProvider] that only forwards
/// [logEvent] while `ConsentCategory.analytics` is
/// [ConsentStatus.granted] — a consuming app registers this instead of
/// its real provider (`Get.put` with `ConsentGatedAnalyticsProvider(realProvider)`,
/// `permanent: true`) so every call site automatically respects consent
/// without individually checking it.
///
/// **Default-deny**: no [ConsentStateService] registered, or consent not
/// yet decided (`ConsentStatus.unknown`) or denied, all silently drop the
/// event — same "chưa consent thì không gửi event" rule
/// [ConsentStateService] itself enforces.
class ConsentGatedAnalyticsProvider implements AnalyticsProvider {
  const ConsentGatedAnalyticsProvider(this._inner);

  final AnalyticsProvider _inner;

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    final granted =
        ConsentStateService.maybe?.isGranted(ConsentCategory.analytics) ??
        false;
    if (!granted) return;
    _inner.logEvent(name, params);
  }
}
