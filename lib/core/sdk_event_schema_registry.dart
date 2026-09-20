import 'analytics_provider.dart';
import 'crash_reporter.dart';
import 'sdk_health_report.dart';

enum EventParamType { string, int, double, bool }

/// What to do with a param key an [EventSchema] doesn't declare.
enum UnknownFieldPolicy {
  /// Silently omit it from the sanitized params sent to the real
  /// provider — no violation recorded, this is expected/allowed noise
  /// (a looser client sending extra debug fields, say).
  drop,

  /// Reject the whole event — for a schema strict enough that an
  /// unrecognized field signals a real integration bug worth surfacing.
  reject,
}

/// One declared param — [pii] means "this key, if present, is ALWAYS
/// stripped before the event reaches a real [AnalyticsProvider]," full
/// stop, independent of [required]/[type] (see [EventSchema]'s
/// constructor for why a param can never be both `required` and `pii`).
class EventParamSchema {
  const EventParamSchema({required this.type, this.required = false, this.pii = false});

  final EventParamType type;
  final bool required;
  final bool pii;
}

/// One event's contract — name, param shape, and how to handle an
/// unrecognized field. [migrate] upgrades an older client's raw params to
/// what THIS (current) schema version expects, applied before validation
/// — same "migrate on read" convention `VersionedJsonStore.migrate`
/// already uses in this package, so an app that can't ship a client
/// update immediately still has its old-shaped events validated
/// correctly against the newest schema.
class EventSchema {
  EventSchema({
    required this.name,
    required this.version,
    required this.params,
    this.unknownFieldPolicy = UnknownFieldPolicy.drop,
    this.migrate,
  }) {
    for (final entry in params.entries) {
      if (entry.value.required && entry.value.pii) {
        throw ArgumentError(
          'Event "$name": param "${entry.key}" không thể vừa required vừa '
          'pii — pii luôn bị redact nên nó sẽ luôn "thiếu", làm required '
          'vô nghĩa (và luôn reject event).',
        );
      }
    }
  }

  final String name;
  final int version;
  final Map<String, EventParamSchema> params;
  final UnknownFieldPolicy unknownFieldPolicy;
  final Map<String, Object?> Function(Map<String, Object?> raw)? migrate;
}

/// The outcome of validating one `logEvent` call — [sanitizedParams] is
/// what's actually safe to forward to a real provider (empty when
/// [accepted] is `false`: a rejected event is never partially sent).
class EventValidationResult {
  const EventValidationResult({
    required this.accepted,
    required this.sanitizedParams,
    required this.violations,
  });

  final bool accepted;
  final Map<String, Object?> sanitizedParams;

  /// Human-readable reasons — populated for both accepted-with-redaction
  /// (a pii field silently dropped) and outright-rejected events, so an
  /// audit trail always has context, not just a bare pass/fail.
  final List<String> violations;
}

/// One [SdkEventSchemaRegistry.validate] call's outcome, kept in a
/// bounded history — same ring-buffer convention
/// `MemoryWatchdog`/`RemoteKillSwitchController` already use in this
/// package.
class EventAuditRecord {
  const EventAuditRecord({
    required this.name,
    required this.accepted,
    required this.violations,
    required this.decidedAtMs,
  });

  final String name;
  final bool accepted;
  final List<String> violations;
  final int decidedAtMs;
}

bool _matchesType(Object? value, EventParamType type) => switch (type) {
  EventParamType.string => value is String,
  EventParamType.int => value is int,
  EventParamType.double => value is double || value is int,
  EventParamType.bool => value is bool,
};

/// Validates event name/params against registered [EventSchema]s before
/// anything reaches a real [AnalyticsProvider] — default-deny at 2
/// levels: an unregistered event name is rejected outright, and a
/// registered event's own unknown/pii fields are handled per the
/// schema's own policy rather than passed through untouched.
class SdkEventSchemaRegistry {
  SdkEventSchemaRegistry({int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _nowMs;
  final Map<String, EventSchema> _schemas = {};
  final List<EventAuditRecord> _auditLog = [];

  /// Bounded audit history cap — same reasoning as
  /// `ReplayRecorder`/`MemoryWatchdog`'s own capped lists.
  static const int _auditCapacity = 200;

  void register(EventSchema schema) => _schemas[schema.name] = schema;

  void registerAll(Iterable<EventSchema> schemas) {
    for (final schema in schemas) {
      register(schema);
    }
  }

  /// Every validation decision made, oldest first, capped at
  /// [_auditCapacity].
  List<EventAuditRecord> get auditLog => List.unmodifiable(_auditLog);

  /// Validates [name]/[params] against the registered schema —
  /// rejection reasons (unknown event, missing required param, a
  /// required param's wrong type, an unknown field under a `reject`
  /// policy) all set [EventValidationResult.accepted] to `false`; a pii
  /// field or a dropped unknown field under a `drop` policy is silently
  /// redacted/omitted without rejecting the rest of the event.
  EventValidationResult validate(String name, Map<String, Object?>? params) {
    final schema = _schemas[name];
    if (schema == null) {
      return _record(
        name,
        const EventValidationResult(
          accepted: false,
          sanitizedParams: {},
          violations: ['unknown event name — chưa đăng ký schema'],
        ),
      );
    }

    final raw = schema.migrate?.call(params ?? const {}) ?? (params ?? const {});
    final sanitized = <String, Object?>{};
    final violations = <String>[];
    var reject = false;

    for (final entry in schema.params.entries) {
      final key = entry.key;
      final paramSchema = entry.value;
      final hasKey = raw.containsKey(key);

      if (paramSchema.pii) {
        if (hasKey) {
          violations.add('param "$key" bị redact vì đánh dấu pii');
        }
        continue;
      }

      if (!hasKey) {
        if (paramSchema.required) {
          violations.add('thiếu param bắt buộc "$key"');
          reject = true;
        }
        continue;
      }

      final value = raw[key];
      if (!_matchesType(value, paramSchema.type)) {
        violations.add('param "$key" sai type (cần ${paramSchema.type.name})');
        if (paramSchema.required) reject = true;
        continue;
      }

      sanitized[key] = value;
    }

    for (final key in raw.keys) {
      if (schema.params.containsKey(key)) continue;
      if (schema.unknownFieldPolicy == UnknownFieldPolicy.reject) {
        violations.add('param lạ "$key" không có trong schema (policy: reject)');
        reject = true;
      }
    }

    return _record(
      name,
      EventValidationResult(
        accepted: !reject,
        sanitizedParams: reject ? const {} : sanitized,
        violations: violations,
      ),
    );
  }

  EventValidationResult _record(String name, EventValidationResult result) {
    _auditLog.add(
      EventAuditRecord(
        name: name,
        accepted: result.accepted,
        violations: result.violations,
        decidedAtMs: _nowMs(),
      ),
    );
    while (_auditLog.length > _auditCapacity) {
      _auditLog.removeAt(0);
    }
    return result;
  }
}

/// Decorator over a real [AnalyticsProvider] — validates every event
/// through [registry] first, forwarding only [EventValidationResult.sanitizedParams]
/// when accepted, dropping it silently otherwise (never partially, never
/// raw). Same decorator shape `ConsentGatedAnalyticsProvider` already
/// uses, so it composes: `SchemaValidatedAnalyticsProvider(ConsentGatedAnalyticsProvider(real), registry)`.
///
/// **A throwing inner provider never reaches caller code** — gameplay
/// code calling `logEvent` (directly, or via `AnalyticsProvider.maybe`)
/// must never crash because a real analytics SDK's network call failed;
/// the error is forwarded to `CrashReporter.maybe` instead (visible in
/// production without crashing anything, `dlog()`'s exact reasoning for
/// existing) and swallowed.
class SchemaValidatedAnalyticsProvider implements AnalyticsProvider {
  const SchemaValidatedAnalyticsProvider(this._inner, this.registry);

  final AnalyticsProvider _inner;
  final SdkEventSchemaRegistry registry;

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    final result = registry.validate(name, params);
    if (!result.accepted) return;
    try {
      _inner.logEvent(name, result.sanitizedParams);
    } catch (error, stack) {
      CrashReporter.maybe?.recordError(
        error,
        stack,
        reason: 'AnalyticsProvider.logEvent threw for event "$name"',
      );
    }
  }
}

/// Opt-in `SdkHealthReport` (FEAT-39) section reporting recent event
/// validation activity — a consumer registers this itself, same reasoning
/// `memoryWatchdogHealthCollector` (FEAT-74) isn't part of
/// `defaultHealthCollectors()`: it needs a specific [registry] instance,
/// not a module a consumer either has or hasn't registered.
HealthCollectorSpec eventSchemaAuditHealthCollector(SdkEventSchemaRegistry registry) =>
    HealthCollectorSpec(
      name: 'eventSchemaAudit',
      allowedKeys: const {'totalEvents', 'rejectedCount', 'lastRejectedReasons'},
      collect: () {
        final log = registry.auditLog;
        final rejected = log.where((r) => !r.accepted).toList();
        return {
          'totalEvents': log.length,
          'rejectedCount': rejected.length,
          'lastRejectedReasons': rejected.isEmpty ? const <String>[] : rejected.last.violations,
        };
      },
    );
