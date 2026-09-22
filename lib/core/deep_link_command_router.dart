import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'utils/clamped_clock.dart';
import 'utils/sdk_result.dart';

/// One allowlisted route: `scheme`/`host`/path shape → a typed command.
/// A path segment starting with `:` captures that segment as a param (e.g.
/// `['level', ':id']` matches `/level/42` and captures `id: '42'`).
class DeepLinkRoute {
  const DeepLinkRoute({
    required this.commandType,
    required this.scheme,
    required this.pathSegments,
    this.host,
  });

  final String commandType;
  final String scheme;

  /// `null` matches any host (or no host at all, e.g. a custom-scheme URI
  /// with no authority).
  final String? host;
  final List<String> pathSegments;
}

/// Immutable, already-validated deep link — path params and query params
/// merged into one map (a query key never overrides a path param of the
/// same name, since path params are captured first).
class DeepLinkCommand {
  const DeepLinkCommand({
    required this.type,
    required this.params,
    required this.raw,
  });

  final String type;
  final Map<String, String> params;
  final Uri raw;
}

/// Pure parser — no I/O, no singletons — matches [uri] against [routes] in
/// order, first match wins. Rejects (never throws) on: a URI longer than
/// [maxLength] (guards against an oversized query string), a scheme/host
/// not in any route, or a path that doesn't match any route's shape.
SdkResult<DeepLinkCommand> parseDeepLink(
  Uri uri,
  List<DeepLinkRoute> routes, {
  int maxLength = 2048,
}) {
  if (uri.toString().length > maxLength) {
    return const SdkFailure(
      kind: SdkErrorKind.validation,
      message: 'Deep link exceeds max length',
    );
  }
  for (final route in routes) {
    if (route.scheme != uri.scheme) continue;
    if (route.host != null && route.host != uri.host) continue;
    final segments = uri.pathSegments;
    if (segments.length != route.pathSegments.length) continue;

    final params = <String, String>{};
    var matched = true;
    for (var i = 0; i < segments.length; i++) {
      final pattern = route.pathSegments[i];
      if (pattern.startsWith(':')) {
        params[pattern.substring(1)] = segments[i];
      } else if (pattern != segments[i]) {
        matched = false;
        break;
      }
    }
    if (!matched) continue;

    // BUG-50: query params must never override a path param of the same
    // name (see the class doc comment above) — `putIfAbsent`, not `addAll`.
    uri.queryParameters.forEach((k, v) => params.putIfAbsent(k, () => v));
    return SdkSuccess(
      DeepLinkCommand(type: route.commandType, params: params, raw: uri),
    );
  }
  return SdkFailure(
    kind: SdkErrorKind.validation,
    message: 'No route matches $uri',
  );
}

enum DeepLinkOutcome {
  dispatched,
  queuedUntilReady,
  duplicateIgnored,
  rejected,
}

/// One handler's result for a single dispatch — diagnostic only, never
/// aborts the rest of the dispatch loop.
class DeepLinkHandlerResult {
  const DeepLinkHandlerResult({
    required this.priority,
    required this.succeeded,
    this.error,
  });

  final int priority;
  final bool succeeded;
  final Object? error;
}

class DeepLinkHandleResult {
  const DeepLinkHandleResult({
    required this.outcome,
    this.command,
    this.handlerResults = const [],
    this.rejectionMessage,
  });

  final DeepLinkOutcome outcome;

  /// `null` only when [outcome] is [DeepLinkOutcome.rejected] (couldn't
  /// even parse a command out of the URI).
  final DeepLinkCommand? command;
  final List<DeepLinkHandlerResult> handlerResults;
  final String? rejectionMessage;
}

typedef DeepLinkHandler = FutureOr<void> Function(DeepLinkCommand command);

/// Parses deep links into typed [DeepLinkCommand]s and dispatches them to
/// registered handlers — no concrete deep-link plugin dependency (`app_links`,
/// `uni_links`, ...); a consuming app feeds its own URI stream into
/// [handleUri].
///
/// **Not-ready queue**: a link arriving before [markReady] is called is
/// queued (never dropped, never dispatched early) and drained exactly once
/// when [markReady] runs — a duplicate arriving twice before ready is only
/// queued once.
///
/// **Dedup**: the same URI arriving again within [dedupeCooldown] of its
/// last dispatch is ignored — covers both the same-process double-delivery
/// some platforms do on relaunch and 2 concurrent calls for the same link
/// (the cooldown timestamp is stamped synchronously before any handler
/// awaits, so 2 back-to-back calls resolve deterministically: the first
/// dispatches, the second is deduped).
///
/// **Handler isolation**: every registered handler for a command type runs
/// (highest [registerHandler] priority first) even if an earlier one
/// throws — a throw is captured into that entry's [DeepLinkHandlerResult],
/// never rethrown, and never affects a different command's dispatch.
class DeepLinkCommandRouter extends GetxService {
  DeepLinkCommandRouter({
    required this.routes,
    this.dedupeCooldown = const Duration(seconds: 3),
    this.maxUriLength = 2048,
  });

  final List<DeepLinkRoute> routes;
  final Duration dedupeCooldown;
  final int maxUriLength;

  static DeepLinkCommandRouter? get maybe =>
      Get.isRegistered<DeepLinkCommandRouter>()
      ? Get.find<DeepLinkCommandRouter>()
      : null;

  bool _ready = false;
  final _pendingBeforeReady = <Uri>[];
  final _handlers = <String, List<({int priority, DeepLinkHandler handler})>>{};
  final _lastHandledAtMs = <String, int>{};

  void registerHandler(
    String commandType,
    DeepLinkHandler handler, {
    int priority = 0,
  }) {
    final list = _handlers.putIfAbsent(commandType, () => []);
    list.add((priority: priority, handler: handler));
    list.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Removes the specific [handler] previously registered for [commandType]
  /// via [registerHandler] (matched by function identity) — a no-op if it
  /// was never registered, or was already removed. This router is a
  /// `Get.put(..., permanent: true)` singleton that outlives any single
  /// screen (see class doc), so a caller registering from a `State.initState`
  /// (e.g. a closure that calls `setState`) must unregister the SAME
  /// handler in `dispose()`, or it stays reachable — and gets invoked on a
  /// future deep link — forever after that State unmounts. Other handlers
  /// registered for the SAME [commandType] (this router supports more than
  /// one per type, dispatched by priority) are left untouched.
  void unregisterHandler(String commandType, DeepLinkHandler handler) {
    final list = _handlers[commandType];
    if (list == null) return;
    list.removeWhere((entry) => entry.handler == handler);
    if (list.isEmpty) _handlers.remove(commandType);
  }

  /// Number of handlers currently registered for [commandType] — a testing
  /// seam for proving a `registerHandler`/`unregisterHandler` pair (e.g. in
  /// a `State`'s `initState`/`dispose`) doesn't leak an orphaned handler.
  @visibleForTesting
  int handlerCountFor(String commandType) =>
      _handlers[commandType]?.length ?? 0;

  /// Marks the router ready to dispatch — drains every link queued while
  /// not ready, each exactly once. A second call is a no-op.
  void markReady() {
    if (_ready) return;
    _ready = true;
    final pending = [..._pendingBeforeReady];
    _pendingBeforeReady.clear();
    for (final uri in pending) {
      unawaited(handleUri(uri));
    }
  }

  Future<DeepLinkHandleResult> handleUri(Uri uri) async {
    final parsed = parseDeepLink(uri, routes, maxLength: maxUriLength);
    if (parsed is SdkFailure<DeepLinkCommand>) {
      return DeepLinkHandleResult(
        outcome: DeepLinkOutcome.rejected,
        rejectionMessage: parsed.message,
      );
    }
    final command = (parsed as SdkSuccess<DeepLinkCommand>).value;

    if (!_ready) {
      final key = uri.toString();
      if (_pendingBeforeReady.any((u) => u.toString() == key)) {
        return DeepLinkHandleResult(
          outcome: DeepLinkOutcome.duplicateIgnored,
          command: command,
        );
      }
      _pendingBeforeReady.add(uri);
      return DeepLinkHandleResult(
        outcome: DeepLinkOutcome.queuedUntilReady,
        command: command,
      );
    }

    final dedupeKey = uri.toString();
    final now = nowMsClamped();
    final lastAt = _lastHandledAtMs[dedupeKey];
    if (lastAt != null && now - lastAt < dedupeCooldown.inMilliseconds) {
      return DeepLinkHandleResult(
        outcome: DeepLinkOutcome.duplicateIgnored,
        command: command,
      );
    }
    _lastHandledAtMs[dedupeKey] = now;

    final results = <DeepLinkHandlerResult>[];
    for (final entry in List.of(_handlers[command.type] ?? const [])) {
      try {
        await entry.handler(command);
        results.add(
          DeepLinkHandlerResult(priority: entry.priority, succeeded: true),
        );
      } catch (error) {
        results.add(
          DeepLinkHandlerResult(
            priority: entry.priority,
            succeeded: false,
            error: error,
          ),
        );
      }
    }
    return DeepLinkHandleResult(
      outcome: DeepLinkOutcome.dispatched,
      command: command,
      handlerResults: results,
    );
  }
}
