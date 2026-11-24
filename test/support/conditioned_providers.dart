import 'dart:async';

import 'package:roy_casual_kit/core/cloud_save_provider.dart';
import 'package:roy_casual_kit/core/offline_outbox_service.dart';

/// What the next call to a conditioned provider does. Consumed in order; once
/// the script is exhausted the provider behaves as [NetStep.ok].
enum NetStep {
  /// Completes normally.
  ok,

  /// Throws a transport error right away (dropped connection, DNS failure).
  fail,

  /// Never completes (a hung socket); only a caller-side timeout ends it.
  hang,

  /// Completes, but only after a caller-controlled gate: see `release`.
  slow,
}

/// A scripted, deterministic stand-in for the network, for ENH-125.
///
/// Nothing here sleeps or reads a real clock: "latency" is a [Completer] the
/// test releases, so tests assert ordering instead of waiting. This is a test
/// helper, deliberately not part of the package's public API.
class NetworkScript {
  NetworkScript([Iterable<NetStep> steps = const []])
    : _steps = List.of(steps);

  final List<NetStep> _steps;

  /// How many calls reached the provider (every call counts, even failures).
  int calls = 0;

  /// Completers of calls currently parked on [NetStep.slow].
  final List<Completer<void>> parked = [];

  /// Pass a [NetStep] only if one is left; otherwise [NetStep.ok].
  NetStep next() {
    calls++;
    return _steps.isEmpty ? NetStep.ok : _steps.removeAt(0);
  }

  /// Applies the next step: returns normally, throws, hangs or parks.
  Future<void> apply(String what) async {
    switch (next()) {
      case NetStep.ok:
        return;
      case NetStep.fail:
        throw TransportError('$what: connection dropped');
      case NetStep.hang:
        await Completer<void>().future;
      case NetStep.slow:
        final gate = Completer<void>();
        parked.add(gate);
        await gate.future;
    }
  }

  /// Releases the oldest parked [NetStep.slow] call.
  void release() => parked.removeAt(0).complete();
}

class TransportError implements Exception {
  TransportError(this.message);
  final String message;

  @override
  String toString() => 'TransportError($message)';
}

/// A [CloudSaveProvider] whose `download`/`upload` follow a [NetworkScript].
class ConditionedCloudSaveProvider implements CloudSaveProvider {
  ConditionedCloudSaveProvider({
    NetworkScript? download,
    NetworkScript? upload,
    this.remote,
  }) : downloadScript = download ?? NetworkScript(),
       uploadScript = upload ?? NetworkScript();

  final NetworkScript downloadScript;
  final NetworkScript uploadScript;

  /// What the "server" holds; `upload` replaces it, `download` returns it.
  Map<String, Object?>? remote;

  /// Every payload that reached the server, in arrival order.
  final List<Map<String, Object?>> uploaded = [];

  @override
  Future<void> signIn() async {}

  @override
  Future<Map<String, Object?>?> download() async {
    await downloadScript.apply('download');
    return remote;
  }

  @override
  Future<void> upload(Map<String, Object?> data) async {
    await uploadScript.apply('upload');
    uploaded.add(Map.of(data));
    remote = Map.of(data);
  }
}

/// An [OutboxUploader] that follows a [NetworkScript] and records what the
/// "server" saw, so tests can assert order and duplicates.
class ConditionedOutboxUploader {
  ConditionedOutboxUploader([NetworkScript? script])
    : script = script ?? NetworkScript();

  final NetworkScript script;

  /// `idempotencyKey` of every upload that was ACKed by the server, in order.
  final List<String> acked = [];

  Future<SyncOutcome> call(
    Map<String, Object?> payload,
    String idempotencyKey,
  ) async {
    await script.apply('outbox upload $idempotencyKey');
    acked.add(idempotencyKey);
    return const SyncAck();
  }
}
