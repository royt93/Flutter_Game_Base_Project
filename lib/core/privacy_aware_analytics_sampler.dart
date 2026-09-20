import 'analytics_provider.dart';
import 'app_session_tracker.dart';
import 'consent_state_service.dart';
import 'crash_reporter.dart';
import 'sdk_event_schema_registry.dart';
import 'utils/fnv1a.dart';

/// Why one `logEvent` call never reached the real [AnalyticsProvider].
enum AnalyticsDropReason {
  consentNotGranted,
  sampledOut,
  schemaRejected,
  rateLimited,
}

/// Bounded, always-consistent counters — never resets on its own, so a
/// health/debug surface can read cumulative drop counts for the process
/// lifetime.
class AnalyticsSamplingAudit {
  const AnalyticsSamplingAudit({
    required this.forwarded,
    required this.droppedByReason,
  });

  final int forwarded;
  final Map<AnalyticsDropReason, int> droppedByReason;

  int get totalDropped =>
      droppedByReason.values.fold(0, (sum, count) => sum + count);
}

/// Decorator over a real [AnalyticsProvider] (FEAT-83) combining 3 privacy/
/// volume controls, each independently audit-countable via [auditSnapshot]:
///
/// 1. **Consent gate** — same default-deny rule [ConsentGatedAnalyticsProvider]
///    already enforces (no [ConsentStateService] registered, or
///    `ConsentCategory.analytics` not [ConsentStatus.granted], drops the
///    event). Duplicated here (not composed via that decorator) so this
///    class stays a single drop-in registration point with one combined
///    audit trail — [analyticsProvider.dart]'s own contract makes the check
///    itself trivial (1 line), so the duplication costs nothing real.
/// 2. **Deterministic sampling** — [sessionSeed] (defaults to
///    [AppSessionTracker.current]'s `sessionId`) + the event name are hashed
///    via [fnv1aHash] into a stable bucket, so the SAME event name within
///    the SAME session always gets the SAME keep/drop decision. This matters
///    for funnel counts: a per-call coin flip would let event #1 of a
///    repeating action survive while event #2 in the same session silently
///    vanishes, corrupting any per-session aggregate. [defaultSamplingRate]
///    applies unless [samplingRateOverrides] names that event specifically.
/// 3. **PII redaction, before anything else downstream** — when [registry]
///    is supplied, every event is validated through it (same
///    [SdkEventSchemaRegistry] FEAT-77 already ships) BEFORE the rate-limit
///    check and BEFORE reaching [AnalyticsProvider] itself — a `pii`-marked
///    field, or an outright schema rejection, never reaches the rate
///    limiter's counters or the real provider.
/// 4. **Rate limit / backpressure** — a fixed-window counter
///    ([maxEventsPerWindow] per [windowSize]); once the window's budget is
///    spent, further events in that window are dropped immediately
///    (`AnalyticsDropReason.rateLimited`) rather than buffered — gameplay
///    code calling [logEvent] never blocks or awaits anything, and an
///    unbounded buffer that never gets flushed (e.g. offline) can never
///    grow — dropping IS the backpressure, not a queue with its own
///    lifecycle to manage.
///
/// A throwing inner provider is caught and forwarded to [CrashReporter.maybe]
/// (same contract [SchemaValidatedAnalyticsProvider] already uses) — never
/// crashes gameplay code.
class PrivacyAwareAnalyticsSampler implements AnalyticsProvider {
  PrivacyAwareAnalyticsSampler(
    this._inner, {
    this.registry,
    double defaultSamplingRate = 1.0,
    Map<String, double> samplingRateOverrides = const {},
    this.maxEventsPerWindow = 20,
    this.windowSize = const Duration(seconds: 1),
    String Function()? sessionSeed,
    int Function()? nowMs,
  }) : defaultSamplingRate = _validatedRate(
         defaultSamplingRate,
         'defaultSamplingRate',
       ),
       samplingRateOverrides = {
         for (final entry in samplingRateOverrides.entries)
           entry.key: _validatedRate(
             entry.value,
             'samplingRateOverrides["${entry.key}"]',
           ),
       },
       _sessionSeed = sessionSeed ?? _defaultSessionSeed,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AnalyticsProvider _inner;

  /// Optional PII/shape gate — omit to pass every param through unredacted
  /// (a consumer relying purely on this sampler's consent/sampling/rate
  /// controls without a schema registry).
  final SdkEventSchemaRegistry? registry;

  /// Sampling rate for an event name not listed in [samplingRateOverrides].
  /// `1.0` (default) never drops for sampling; `0.0` always does.
  final double defaultSamplingRate;

  /// Per-event-name sampling rate, takes precedence over [defaultSamplingRate].
  final Map<String, double> samplingRateOverrides;

  /// Max events forwarded within one [windowSize] window before further
  /// events in that same window are dropped.
  final int maxEventsPerWindow;
  final Duration windowSize;

  final String Function() _sessionSeed;
  final int Function() _nowMs;

  int _forwarded = 0;
  final Map<AnalyticsDropReason, int> _dropped = {
    for (final reason in AnalyticsDropReason.values) reason: 0,
  };
  int _windowStartMs = 0;
  int _windowCount = 0;

  /// Cumulative forwarded/dropped-by-reason counts since construction.
  AnalyticsSamplingAudit get auditSnapshot => AnalyticsSamplingAudit(
    forwarded: _forwarded,
    droppedByReason: Map.unmodifiable(_dropped),
  );

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    final granted =
        ConsentStateService.maybe?.isGranted(ConsentCategory.analytics) ??
        false;
    if (!granted) {
      _drop(AnalyticsDropReason.consentNotGranted);
      return;
    }

    if (!_isSampledIn(name)) {
      _drop(AnalyticsDropReason.sampledOut);
      return;
    }

    var sanitized = params ?? const <String, Object?>{};
    final activeRegistry = registry;
    if (activeRegistry != null) {
      final result = activeRegistry.validate(name, params);
      if (!result.accepted) {
        _drop(AnalyticsDropReason.schemaRejected);
        return;
      }
      sanitized = result.sanitizedParams;
    }

    if (!_allowByRateLimit()) {
      _drop(AnalyticsDropReason.rateLimited);
      return;
    }

    _forwarded++;
    try {
      _inner.logEvent(name, sanitized);
    } catch (error, stack) {
      CrashReporter.maybe?.recordError(
        error,
        stack,
        reason: 'AnalyticsProvider.logEvent threw for event "$name"',
      );
    }
  }

  bool _isSampledIn(String name) {
    final rate = samplingRateOverrides[name] ?? defaultSamplingRate;
    if (rate >= 1.0) return true;
    if (rate <= 0.0) return false;
    final bucket = fnv1aHash('${_sessionSeed()}:$name') % 10000;
    return bucket < (rate * 10000).round();
  }

  bool _allowByRateLimit() {
    final now = _nowMs();
    if (now - _windowStartMs >= windowSize.inMilliseconds) {
      _windowStartMs = now;
      _windowCount = 0;
    }
    if (_windowCount >= maxEventsPerWindow) return false;
    _windowCount++;
    return true;
  }

  void _drop(AnalyticsDropReason reason) {
    _dropped[reason] = (_dropped[reason] ?? 0) + 1;
  }

  static double _validatedRate(double rate, String label) {
    if (rate < 0 || rate > 1 || rate.isNaN) {
      throw ArgumentError.value(rate, label, 'must be within [0, 1]');
    }
    return rate;
  }

  static String _defaultSessionSeed() =>
      AppSessionTracker.maybe?.current.sessionId ?? 'no-session';
}
