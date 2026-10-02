import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';

import 'analytics_provider.dart';
import 'consent_state_service.dart';
import 'sdk_event_schema_registry.dart';
import 'storage_service.dart';
import 'utils/fnv1a.dart';
import 'utils/retry_policy.dart';
import 'utils/sdk_result.dart';

typedef AnalyticsBatchUploader =
    Future<void> Function(List<QueuedAnalyticsEvent> batch);

class QueuedAnalyticsEvent {
  const QueuedAnalyticsEvent({
    required this.id,
    required this.name,
    required this.params,
    required this.sequence,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final Map<String, Object?> params;
  final int sequence;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'params': params,
    'sequence': sequence,
    'createdAtMs': createdAtMs,
  };

  static QueuedAnalyticsEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final params = raw['params'];
    final sequence = raw['sequence'];
    final createdAtMs = raw['createdAtMs'];
    if (id is! String ||
        name is! String ||
        params is! Map ||
        sequence is! int ||
        createdAtMs is! int) {
      return null;
    }
    final safeParams = <String, Object?>{};
    for (final entry in params.entries) {
      if (entry.key is! String || !_isJsonScalar(entry.value)) return null;
      safeParams[entry.key as String] = entry.value;
    }
    return QueuedAnalyticsEvent(
      id: id,
      name: name,
      params: Map.unmodifiable(safeParams),
      sequence: sequence,
      createdAtMs: createdAtMs,
    );
  }
}

enum AnalyticsQueueDropReason {
  consentNotGranted,
  schemaRejected,
  sampledOut,
  queueFull,
}

class AnalyticsQueueAudit {
  const AnalyticsQueueAudit({
    required this.queued,
    required this.uploaded,
    required this.droppedByReason,
  });

  final int queued;
  final int uploaded;
  final Map<AnalyticsQueueDropReason, int> droppedByReason;

  int get totalDropped =>
      droppedByReason.values.fold(0, (sum, count) => sum + count);
}

/// Consent-first, schema-redacted, deterministic-sampled persistent FIFO.
///
/// Upload ACK is all-or-nothing. Callers must make [uploader] idempotent by
/// event [QueuedAnalyticsEvent.id]: a process crash after remote ACK but before
/// persisted removal can replay the same event on the next launch.
class PrivacyAwareAnalyticsQueue implements AnalyticsProvider {
  PrivacyAwareAnalyticsQueue({
    required this.storage,
    required this.consent,
    required this.registry,
    required AnalyticsBatchUploader uploader,
    this.capacity = 1000,
    this.batchSize = 50,
    this.defaultSamplingRate = 1,
    this.samplingRateOverrides = const {},
    this.retryPolicy = const RetryPolicy(),
    RetryExecutor? retryExecutor,
    String Function()? idGenerator,
    int Function()? nowMs,
    String Function()? sessionSeed,
    this.storageKey = StorageKeys.analyticsQueueV1,
  }) : _uploader = uploader,
       _retryExecutor = retryExecutor ?? RetryExecutor(),
       _idGenerator = idGenerator ?? _secureId,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _sessionSeed = sessionSeed ?? (() => 'no-session') {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be > 0');
    }
    if (batchSize <= 0) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be > 0');
    }
    _validateRate(defaultSamplingRate, 'defaultSamplingRate');
    for (final entry in samplingRateOverrides.entries) {
      _validateRate(entry.value, 'samplingRateOverrides["${entry.key}"]');
    }
    _hydrate();
    _consentWorker = ever<int>(consent.revision, (_) {
      if (!consent.isGranted(ConsentCategory.analytics)) {
        unawaited(_purge().catchError((_) {}));
      }
    });
  }

  final StorageService storage;
  final ConsentStateService consent;
  final SdkEventSchemaRegistry registry;
  final int capacity;
  final int batchSize;
  final double defaultSamplingRate;
  final Map<String, double> samplingRateOverrides;
  final RetryPolicy retryPolicy;
  final String storageKey;
  final AnalyticsBatchUploader _uploader;
  final RetryExecutor _retryExecutor;
  final String Function() _idGenerator;
  final int Function() _nowMs;
  final String Function() _sessionSeed;

  final List<QueuedAnalyticsEvent> _pending = [];
  final Map<AnalyticsQueueDropReason, int> _dropped = {
    for (final reason in AnalyticsQueueDropReason.values) reason: 0,
  };
  late final Worker _consentWorker;
  Future<void> _persistenceTail = Future.value();
  Future<SdkResult<int>>? _flushInFlight;
  int _nextSequence = 0;
  int _queued = 0;
  int _uploaded = 0;
  bool _disposed = false;

  int get pendingCount => _pending.length;
  List<QueuedAnalyticsEvent> get pendingEvents => List.unmodifiable(_pending);
  AnalyticsQueueAudit get auditSnapshot => AnalyticsQueueAudit(
    queued: _queued,
    uploaded: _uploaded,
    droppedByReason: Map.unmodifiable(_dropped),
  );

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    unawaited(enqueueDurably(name, params).catchError((_) => false));
  }

  Future<bool> enqueueDurably(
    String name, [
    Map<String, Object?>? params,
  ]) async {
    if (_disposed || !consent.isGranted(ConsentCategory.analytics)) {
      _drop(AnalyticsQueueDropReason.consentNotGranted);
      return false;
    }

    final validation = registry.validate(name, params);
    if (!validation.accepted) {
      _drop(AnalyticsQueueDropReason.schemaRejected);
      return false;
    }
    if (!_sampledIn(name)) {
      _drop(AnalyticsQueueDropReason.sampledOut);
      return false;
    }
    if (_pending.length >= capacity) {
      _drop(AnalyticsQueueDropReason.queueFull);
      return false;
    }

    final event = QueuedAnalyticsEvent(
      id: _idGenerator(),
      name: name,
      params: Map.unmodifiable(validation.sanitizedParams),
      sequence: _nextSequence++,
      createdAtMs: _nowMs(),
    );
    _pending.add(event);
    _queued++;
    try {
      await _persistSnapshot();
      return true;
    } catch (_) {
      _pending.removeWhere((pending) => pending.id == event.id);
      _queued--;
      rethrow;
    }
  }

  Future<void> flushPersistence() => _persistenceTail;

  Future<SdkResult<int>> flush() {
    final existing = _flushInFlight;
    if (existing != null) return existing;
    final future = _flushInternal();
    _flushInFlight = future;
    future.whenComplete(() {
      if (identical(_flushInFlight, future)) _flushInFlight = null;
    });
    return future;
  }

  Future<SdkResult<int>> _flushInternal() async {
    try {
      await flushPersistence();
      if (_disposed || !consent.isGranted(ConsentCategory.analytics)) {
        await _purge();
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Analytics consent not granted',
        );
      }
      if (_pending.isEmpty) return const SdkSuccess(0);

      final batch = List<QueuedAnalyticsEvent>.unmodifiable(
        _pending.take(batchSize),
      );
      final result = await _retryExecutor.run<void>(
        () => _uploader(batch),
        policy: retryPolicy,
      );
      if (!result.isSuccess) {
        return SdkFailure(
          kind: SdkErrorKind.network,
          message: 'Analytics batch upload failed',
          retryable: true,
          cause: (result as SdkFailure<void>).cause,
          stackTrace: result.stackTrace,
        );
      }
      if (!consent.isGranted(ConsentCategory.analytics)) {
        await _purge();
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Analytics consent revoked during upload',
        );
      }

      final ids = batch.map((event) => event.id).toSet();
      final before = _pending.length;
      _pending.removeWhere((event) => ids.contains(event.id));
      final removed = before - _pending.length;
      _uploaded += removed;
      await _persistSnapshot();
      return SdkSuccess(removed);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Analytics queue persistence failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _purge() {
    _pending.clear();
    return _enqueuePersistence(() => storage.remove(storageKey));
  }

  Future<void> _persistSnapshot() {
    final snapshot = List<QueuedAnalyticsEvent>.from(_pending);
    return _enqueuePersistence(() async {
      if (snapshot.isEmpty) {
        await storage.remove(storageKey);
      } else {
        await storage.setString(
          storageKey,
          jsonEncode(snapshot.map((event) => event.toJson()).toList()),
        );
      }
    });
  }

  Future<void> _enqueuePersistence(Future<void> Function() write) {
    final next = _persistenceTail.then(
      (_) => write(),
      onError: (_, _) => write(),
    );
    _persistenceTail = next;
    return next;
  }

  void _hydrate() {
    if (!consent.isGranted(ConsentCategory.analytics)) {
      unawaited(storage.remove(storageKey));
      return;
    }
    final raw = storage.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final value in decoded) {
        final event = QueuedAnalyticsEvent.tryParse(value);
        if (event == null || _pending.length >= capacity) continue;
        _pending.add(event);
        if (event.sequence >= _nextSequence) {
          _nextSequence = event.sequence + 1;
        }
      }
      _pending.sort((a, b) => a.sequence.compareTo(b.sequence));
    } catch (_) {
      _pending.clear();
    }
  }

  bool _sampledIn(String name) {
    final rate = samplingRateOverrides[name] ?? defaultSamplingRate;
    if (rate >= 1) return true;
    if (rate <= 0) return false;
    final bucket = fnv1aHash('${_sessionSeed()}:$name') % 10000;
    return bucket < (rate * 10000).round();
  }

  void _drop(AnalyticsQueueDropReason reason) {
    _dropped[reason] = (_dropped[reason] ?? 0) + 1;
  }

  void dispose() {
    _disposed = true;
    _consentWorker.dispose();
  }

  static void _validateRate(double rate, String name) {
    if (rate.isNaN || rate < 0 || rate > 1) {
      throw ArgumentError.value(rate, name, 'must be within [0, 1]');
    }
  }

  static String _secureId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

bool _isJsonScalar(Object? value) =>
    value == null || value is String || value is num || value is bool;
