import 'dart:convert';

import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';

/// A privacy-relevant capability gated by consent. Deliberately does
/// **not** include "ads" — this kit ships no ads mediation seam by
/// product decision (see FEAT-02's rejection), so there is nothing here
/// to gate for that category.
enum ConsentCategory { analytics, personalization }

enum ConsentStatus { granted, denied, unknown }

enum ConsentSource { user, policyReset }

/// Immutable point-in-time read of one category's consent.
class ConsentRecord {
  const ConsentRecord({
    required this.category,
    required this.status,
    required this.source,
    required this.policyVersion,
    required this.updatedAtMs,
  });

  final ConsentCategory category;
  final ConsentStatus status;
  final ConsentSource source;
  final int policyVersion;
  final int updatedAtMs;
}

/// SSOT for privacy consent, gating which providers (analytics,
/// personalization) are allowed to run.
///
/// **Default-deny**: a category that was never explicitly decided reads as
/// [ConsentStatus.unknown] — never [ConsentStatus.granted] — so
/// [isGranted] is false until a real `grant()` call happens. The same
/// default-deny applies to a corrupted or hand-edited save: an entry that
/// doesn't strictly parse (bad JSON, an unrecognized status string) is
/// treated as unknown, never coerced into granted.
///
/// **Policy version**: [policyVersion] is the app's *current* consent
/// policy version (bump it whenever the privacy policy materially
/// changes). A category persisted under an *older* policy version reads
/// back as [ConsentStatus.unknown] regardless of what it was previously
/// set to — the policy bump forces a fresh decision. Once re-decided
/// under the new version, it stamps that version and stays valid until
/// the next bump.
class ConsentStateService extends GetxService {
  ConsentStateService({required this.policyVersion});

  final int policyVersion;

  /// Gets the instance if already registered (safe to call from call
  /// sites that may run before/without this service registered, e.g.
  /// widget tests).
  static ConsentStateService? get maybe =>
      Get.isRegistered<ConsentStateService>()
      ? Get.find<ConsentStateService>()
      : null;

  /// Bumped on every [grant]/[deny]/[reset] — wrap a read in `Obx` (or
  /// listen to this directly) to rebuild when a category's decision
  /// changes.
  final revision = 0.obs;

  ConsentRecord recordOf(ConsentCategory category) {
    final stored = _readState()[category];
    if (stored == null || stored.policyVersion < policyVersion) {
      return ConsentRecord(
        category: category,
        status: ConsentStatus.unknown,
        source: ConsentSource.policyReset,
        policyVersion: policyVersion,
        updatedAtMs: nowMsClamped(),
      );
    }
    return stored;
  }

  ConsentStatus statusOf(ConsentCategory category) => recordOf(category).status;

  bool isGranted(ConsentCategory category) =>
      statusOf(category) == ConsentStatus.granted;

  void grant(ConsentCategory category) => _set(category, ConsentStatus.granted);

  void deny(ConsentCategory category) => _set(category, ConsentStatus.denied);

  void reset(ConsentCategory category) => _set(category, ConsentStatus.unknown);

  void _set(ConsentCategory category, ConsentStatus status) {
    final state = _readState();
    state[category] = ConsentRecord(
      category: category,
      status: status,
      source: ConsentSource.user,
      policyVersion: policyVersion,
      updatedAtMs: nowMsClamped(),
    );
    _persist(state);
    revision.value++;
  }

  /// Reads the persisted map, dropping (never trusting) any entry that
  /// doesn't strictly parse into a real [ConsentRecord] — a corrupted or
  /// hand-edited entry is treated as if it had never been decided
  /// (never-decided == unknown), never coerced into [ConsentStatus.granted].
  Map<ConsentCategory, ConsentRecord> _readState() {
    final raw = StorageService.to.getString(StorageKeys.consentStateV1);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <ConsentCategory, ConsentRecord>{};
      for (final entry in decoded.entries) {
        final category = _categoryByName(entry.key);
        final value = entry.value;
        if (category == null || value is! Map) continue;
        final status = _statusByName(value['status']);
        final source = _sourceByName(value['source']);
        final storedVersion = value['policyVersion'];
        final updatedAtMs = value['updatedAtMs'];
        if (status == null ||
            source == null ||
            storedVersion is! int ||
            updatedAtMs is! int) {
          continue;
        }
        result[category] = ConsentRecord(
          category: category,
          status: status,
          source: source,
          policyVersion: storedVersion,
          updatedAtMs: updatedAtMs,
        );
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  void _persist(Map<ConsentCategory, ConsentRecord> state) {
    final json = {
      for (final entry in state.entries)
        entry.key.name: {
          'status': entry.value.status.name,
          'source': entry.value.source.name,
          'policyVersion': entry.value.policyVersion,
          'updatedAtMs': entry.value.updatedAtMs,
        },
    };
    StorageService.to.setString(StorageKeys.consentStateV1, jsonEncode(json));
  }

  static ConsentCategory? _categoryByName(Object? name) {
    for (final c in ConsentCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  static ConsentStatus? _statusByName(Object? name) {
    for (final s in ConsentStatus.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  static ConsentSource? _sourceByName(Object? name) {
    for (final s in ConsentSource.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}
