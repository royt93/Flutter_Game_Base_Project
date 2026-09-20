import 'dart:ui' show Locale;

import 'package:get/get.dart';

/// Vowel → accented look-alike, same technique Android/iOS's own official
/// pseudolocalization tooling uses — a HARDCODED string that bypassed
/// `AppTranslations`/`.tr` stays perfectly plain ASCII while every real
/// translated string comes back accented, making the gap visually
/// obvious without reading code.
const Map<String, String> _accentMap = {
  'a': 'á',
  'e': 'é',
  'i': 'í',
  'o': 'ó',
  'u': 'ú',
  'A': 'Á',
  'E': 'É',
  'I': 'Í',
  'O': 'Ó',
  'U': 'Ú',
};

/// Deterministically transforms [value] into a "pseudo-localized" string:
/// every vowel becomes its accented look-alike (see [_accentMap]'s doc),
/// the string is padded to roughly 40% longer (the commonly-cited
/// average real-world translation expansion factor — stress-tests
/// overflow before a real translator ever touches the key), and the
/// whole thing is wrapped in `[[...]]` so a truncated render (a missing
/// closing `]]`) is visually obvious too.
///
/// Deterministic and pure — the same [value] always produces the exact
/// same output, no randomness, so a golden/widget test asserting on the
/// result never flakes.
String pseudoLocalize(String value) {
  final accented = value.split('').map((c) => _accentMap[c] ?? c).join();
  final paddingLength = (value.length * 0.4).ceil().clamp(1, 1 << 30);
  final padding = 'x' * paddingLength;
  return '[[$accented $padding]]';
}

/// A GetX [Translations] that wraps [baseKeys] (typically a real locale's
/// map, e.g. `AppTranslations().keys['en']!`) with [pseudoLocalize] on
/// every value — every key [baseKeys] has is covered by construction (the
/// `keys` getter maps every entry, never a subset).
///
/// **Never included in `AppTranslations.supported` or any production
/// locale list** — this exists purely for a debug/QA build flavor
/// (`GetMaterialApp(translations: PseudoLocaleTranslations(...), locale:
/// PseudoLocaleTranslations.defaultLocale)`) to catch hardcoded strings
/// and overflow before a real translation ever ships, same "opt-in only,
/// never leaks into a normal build" discipline `runtime_flags.isE2eTest`
/// already establishes for a different debug-only concern.
class PseudoLocaleTranslations extends Translations {
  PseudoLocaleTranslations({
    this.locale = defaultLocale,
    required this.baseKeys,
  });

  /// `qps`/`PLOC` — same synthetic-locale convention Android's own
  /// pseudolocalization tooling uses, chosen specifically so it can never
  /// collide with a real BCP-47 locale a translator would ship.
  static const defaultLocale = Locale('qps', 'PLOC');

  final Locale locale;
  final Map<String, String> baseKeys;

  String get localeKey => '${locale.languageCode}_${locale.countryCode}';

  @override
  Map<String, Map<String, String>> get keys => {
    localeKey: {
      for (final entry in baseKeys.entries)
        entry.key: pseudoLocalize(entry.value),
    },
  };
}
