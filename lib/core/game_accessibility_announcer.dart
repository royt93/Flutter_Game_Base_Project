import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_translations.dart';
import 'game_event_bus.dart';
import 'locale_service.dart';
import 'storage_service.dart';

/// Broad bucket a [GameAccessibilityEvent] falls into — used only to rate-
/// limit/coalesce a burst (several level-ups from one big XP grant, several
/// reward lines from one combined claim) so a screen reader isn't spammed
/// with overlapping announcements. Not tied to any specific kit service —
/// [GameAccessibilityCategory.custom] covers anything a consumer app wants
/// to announce that isn't one of the 3 common casual-game moments.
enum GameAccessibilityCategory { levelUp, reward, lives, custom }

/// A gameplay moment worth announcing to a screen reader — fired on a
/// [GameEventBus] like any other [GameEvent] (FEAT-88's pattern), so a
/// consumer's own service (progression, reward pipeline, energy) emits one
/// of these at the point it already changes that state, without needing to
/// know [GameAccessibilityAnnouncer] exists.
///
/// [translationKey] is looked up in [AppTranslations] and interpolated with
/// [parameters] (each `{key}` in the string replaced by its value) — kept
/// as a translation key rather than a raw string so the same event reads
/// correctly in every [AppTranslations.supported] locale.
class GameAccessibilityEvent extends GameEvent {
  GameAccessibilityEvent({
    required this.category,
    required this.translationKey,
    Map<String, String> parameters = const {},
  }) : parameters = Map.unmodifiable(parameters) {
    if (translationKey.isEmpty) {
      throw ArgumentError.value(
        translationKey,
        'translationKey',
        'must not be empty',
      );
    }
  }

  final GameAccessibilityCategory category;
  final String translationKey;
  final Map<String, String> parameters;
}

/// Bridges [GameAccessibilityEvent]s from a [GameEventBus] to a screen
/// reader — the piece this kit was missing (widgets carry their own
/// `Semantics`, but nothing announced a fast state CHANGE like "level up"
/// or "+50 gems").
///
/// Deliberately platform-channel-free: [announce] is an injected callback
/// (same seam convention as `ReviewPromptTrigger.showReview`), not a direct
/// `SemanticsService` call, so this class stays pure-Dart/unit-testable and
/// isn't pinned to one Flutter version's exact semantics-announcement API
/// (which has changed once already — `SemanticsService.announce` is
/// deprecated in favor of `SemanticsService.sendAnnouncement`, which needs a
/// `FlutterView`). A consumer widget wires the real call, typically:
/// ```dart
/// GameAccessibilityAnnouncer(
///   eventBus: eventBus,
///   announce: (message) => SemanticsService.sendAnnouncement(
///     View.of(context),
///     message,
///     TextDirection.ltr,
///   ),
/// );
/// ```
class GameAccessibilityAnnouncer {
  GameAccessibilityAnnouncer({
    required GameEventBus eventBus,
    required this.announce,
    this.throttleWindow = const Duration(milliseconds: 1500),
    bool Function()? isEnabled,
    Locale Function()? locale,
    int Function()? nowMs,
  }) : _isEnabled = isEnabled ?? _defaultIsEnabled,
       _locale = locale ?? _defaultLocale,
       _nowMs = nowMs ?? _newStopwatchClock(),
       _translations = AppTranslations().keys {
    if (throttleWindow.isNegative) {
      throw ArgumentError.value(
        throttleWindow,
        'throttleWindow',
        'must not be negative',
      );
    }
    _subscription = eventBus.subscribe<GameAccessibilityEvent>(_onEvent);
  }

  /// Delivers the final, already-localized/interpolated message. May throw
  /// (e.g. the platform channel is unavailable) — a throw is caught and
  /// swallowed so a screen-reader hiccup never crashes gameplay.
  final Future<void> Function(String message) announce;

  /// Minimum gap between 2 announcements of the SAME
  /// [GameAccessibilityCategory] — a burst's first event announces
  /// immediately, later same-category events arriving inside this window
  /// are dropped (leading-edge throttle, same policy as
  /// `utils/throttle.dart`'s `throttled()`).
  final Duration throttleWindow;

  final bool Function() _isEnabled;
  final Locale Function() _locale;
  final int Function() _nowMs;
  final Map<String, Map<String, String>> _translations;
  final _lastAnnouncedAtMs = <GameAccessibilityCategory, int>{};
  late final StreamSubscription<GameEvent> _subscription;

  static bool _defaultIsEnabled() =>
      StorageService.maybe?.getBool(
        StorageKeys.gameA11yAnnouncerEnabled,
        def: true,
      ) ??
      true;

  static Locale _defaultLocale() =>
      LocaleService.maybe?.current.value ?? AppTranslations.fallback;

  static int Function() _newStopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMilliseconds;
  }

  Future<void> _onEvent(GameEvent event) async {
    // AUDIT-FIX: the whole body is now inside this try/catch, not just the
    // final `announce()` call. `_onEvent` is `async`, so its call from
    // `GameEventBus.subscribe`'s listener returns a Future synchronously —
    // a throw from an injected seam (`isEnabled`/`locale`/`nowMs`) surfaces
    // as an unhandled async zone error, not as a caught exception the way a
    // plain synchronous throw would. Any consumer-injected callback here
    // (not just `announce`) must never be able to crash the gameplay bus.
    try {
      if (event is! GameAccessibilityEvent) return;
      if (!_isEnabled()) return;

      final now = _nowMs();
      final lastAt = _lastAnnouncedAtMs[event.category];
      if (lastAt != null && now - lastAt < throttleWindow.inMilliseconds) {
        return;
      }

      final message = _resolve(event);
      if (message == null) return;
      _lastAnnouncedAtMs[event.category] = now;

      await announce(message);
    } catch (_) {
      // A screen-reader/platform-channel failure, or a throwing
      // consumer-injected seam, must never propagate into the gameplay
      // event bus.
    }
  }

  String? _resolve(GameAccessibilityEvent event) {
    final localeCode = _locale().languageCode;
    final template =
        _translations[localeCode]?[event.translationKey] ??
        _translations[AppTranslations.fallback.languageCode]?[event
            .translationKey];
    if (template == null) return null;
    // AUDIT-FIX: substitute in one RegExp pass over the ORIGINAL template.
    // Repeated `replaceAll` per parameter made the result order-dependent:
    // if a value itself contained another parameter's `{key}` syntax, a later
    // loop iteration replaced inside that value too (double substitution).
    return template.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
      final key = match.group(1)!;
      return event.parameters[key] ?? match.group(0)!;
    });
  }

  Future<void> dispose() => _subscription.cancel();
}
