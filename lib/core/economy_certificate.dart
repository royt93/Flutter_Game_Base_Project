import 'economy_wallet.dart';
import 'purchase_ledger_service.dart';
import 'save_integrity.dart';
import 'utils/safe_json.dart';
import 'utils/trusted_clock.dart';

/// Result of [EconomyCertificate.verify] — a single typed status a backend
/// or another device can branch on, instead of re-deriving "is this really
/// trustworthy" from raw HMAC/clock plumbing itself.
enum EconomyCertificateStatus {
  /// Signature checked out AND (when a clock judgement was recorded) the
  /// clock wasn't behaving suspiciously at issue time.
  valid,

  /// The HMAC signature is missing or doesn't match — the certificate was
  /// hand-edited or corrupted. Takes priority over every other check: once
  /// the signature fails, NOTHING else in the payload (including its own
  /// `clockJudgement` field) can be trusted either.
  tampered,

  /// Signature checked out, but [EconomyCertificateVerification.clockJudgement]
  /// was [ClockJudgement.rewind] or [ClockJudgement.suspiciousForwardJump]
  /// at issue time — the economic data itself may be genuine, but it was
  /// captured while the device's clock looked tampered with.
  clockSuspicious,
}

/// Typed result of [EconomyCertificate.verify].
class EconomyCertificateVerification {
  const EconomyCertificateVerification({
    required this.status,
    this.balances,
    this.clockJudgement,
  });

  final EconomyCertificateStatus status;

  /// The certificate's wallet balances snapshot — `null` only for
  /// [EconomyCertificateStatus.tampered] (an unsigned/corrupt payload is
  /// never trusted enough to read a value out of, even one that happens
  /// to parse).
  final Map<String, int>? balances;

  /// The clock judgement recorded at issue time, if the issuer had a
  /// [TrustedClockService] to record one — `null` if none was supplied to
  /// [EconomyCertificate.issue], or the certificate is
  /// [EconomyCertificateStatus.tampered].
  final ClockJudgement? clockJudgement;

  bool get isValid => status == EconomyCertificateStatus.valid;
}

/// Combines a save-integrity signature ([save_integrity.dart]'s
/// `signExport`/`verifyAndStrip`), a [TrustedClockService] judgement, and
/// an [EconomyWallet]/[PurchaseLedgerService] snapshot into 1 "certificate"
/// a backend (or another device) can verify with a single call, instead of
/// re-implementing all 3 checks itself (FEAT-91).
///
/// Deliberately a thin glue layer, not a reimplementation: signing reuses
/// `save_integrity.dart` unchanged (same convention every other signed
/// artifact in this package already uses — [ReplayCapsule.exportSigned],
/// [DiagnosticsExportBundle.sign], `ReproductionCapsule.capture`).
class EconomyCertificate {
  EconomyCertificate._();

  static const int schemaVersion = 1;

  /// Issues a signed certificate: [wallet]'s current balances, plus (if
  /// [ledger] is given) the ledger's balance/ownership for exactly the
  /// SKUs named in [ledgerConsumableSkus]/[ledgerPermanentSkus] —
  /// [PurchaseLedgerService] has no "list every granted SKU" API by
  /// design (a caller-owned catalog, same trust-boundary reasoning as its
  /// own class doc), so the caller names which entries matter for this
  /// certificate — plus (if [trustedClock] is given)
  /// [TrustedClockService.lastJudgement] at issue time. Signed via
  /// [secret].
  static Map<String, Object?> issue({
    required EconomyWallet wallet,
    required String secret,
    PurchaseLedgerService? ledger,
    Set<String> ledgerConsumableSkus = const {},
    Set<String> ledgerPermanentSkus = const {},
    TrustedClockService? trustedClock,
    int Function()? nowMs,
  }) {
    final body = <String, Object?>{
      'schemaVersion': schemaVersion,
      'issuedAtMs': (nowMs ?? (() => DateTime.now().millisecondsSinceEpoch))(),
      'balances': Map<String, int>.from(wallet.balances),
    };

    if (ledger != null) {
      body['ledger'] = {
        'consumables': {
          for (final sku in ledgerConsumableSkus) sku: ledger.balanceOf(sku),
        },
        'permanents': [
          for (final sku in ledgerPermanentSkus)
            if (ledger.owns(sku)) sku,
        ],
      };
    }

    final judgement = trustedClock?.lastJudgement;
    if (judgement != null) {
      body['clockJudgement'] = judgement.name;
    }

    return signExport(body, secret);
  }

  /// Verifies [certificate] against [secret] — never throws; a
  /// missing/mismatched signature (or a malformed shape underneath a
  /// valid one) is reported as [EconomyCertificateStatus.tampered], not a
  /// thrown exception, so a caller can branch on the result directly.
  static EconomyCertificateVerification verify(
    Map<String, Object?> certificate,
    String secret,
  ) {
    final Map<String, Object?> data;
    try {
      data = verifyAndStrip(certificate, secret);
    } on FormatException {
      return const EconomyCertificateVerification(
        status: EconomyCertificateStatus.tampered,
      );
    }

    ClockJudgement? judgement;
    final rawJudgement = data['clockJudgement'];
    if (rawJudgement is String) {
      for (final candidate in ClockJudgement.values) {
        if (candidate.name == rawJudgement) {
          judgement = candidate;
          break;
        }
      }
    }

    final rawBalances = data['balances'];
    final balances = <String, int>{
      if (rawBalances is Map)
        for (final entry in rawBalances.entries)
          entry.key.toString(): asIntOr(entry.value, 0),
    };

    final suspicious =
        judgement == ClockJudgement.rewind ||
        judgement == ClockJudgement.suspiciousForwardJump;

    return EconomyCertificateVerification(
      status: suspicious
          ? EconomyCertificateStatus.clockSuspicious
          : EconomyCertificateStatus.valid,
      balances: balances,
      clockJudgement: judgement,
    );
  }
}
