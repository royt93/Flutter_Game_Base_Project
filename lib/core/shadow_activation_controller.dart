import 'remote_kill_switch_controller.dart';

/// A min/max threshold on 1 named metric — a violation of either bound is
/// what [ShadowActivationController] treats as "this shadow-activated
/// feature/event is misbehaving, roll it back now". Either bound can be
/// `null` (no lower/upper check) — but not BOTH; that invariant is
/// enforced by [ShadowActivationController.registerGuardrail] (ENH-89),
/// not here — a runtime `assert` on this `const`-constructible class
/// would be stripped from release builds anyway, and a genuine
/// `if`/`throw` here would force every `const` guardrail list in
/// consumers off `const`.
class GuardrailDefinition {
  const GuardrailDefinition({required this.metricName, this.min, this.max});

  final String metricName;
  final double? min;
  final double? max;

  bool violatedBy(double value) =>
      (min != null && value < min!) || (max != null && value > max!);
}

/// Watches caller-reported metrics for a feature/event that's been
/// shadow-activated (rolled out to a small cohort ahead of a full
/// release) and auto-rolls-back — CLIENT-SIDE, without waiting for an
/// operator — the instant a registered [GuardrailDefinition] is violated
/// (FEAT-90).
///
/// Deliberately a thin glue layer, not a telemetry/statistics engine:
/// [reportMetric] takes an already-computed numeric reading (an
/// instantaneous value, a rolling average, whatever the caller's own
/// metric means) — this class only owns the threshold check and the
/// rollback trigger, reusing [RemoteKillSwitchController.forceKillLocally]
/// (added alongside this class) rather than maintaining its own separate
/// kill state.
///
/// Cohort bucketing (which players see the shadow-activated feature) is
/// out of scope here — a caller already has `ExperimentBucketingService`
/// for that; this class only answers "should the feature I already
/// rolled out to that cohort be rolled back right now".
class ShadowActivationController {
  ShadowActivationController({required this.killSwitch});

  final RemoteKillSwitchController killSwitch;

  final Map<String, List<GuardrailDefinition>> _guardrails = {};

  /// Registers [guardrail] for [featureId]. A feature can have several
  /// guardrails (e.g. both an earn-rate ceiling and a spend-rate floor);
  /// any single violation is enough to trigger rollback.
  ///
  /// ENH-89: GuardrailDefinition's own `min`/`max` invariant is only an
  /// `assert` (stripped in release builds) — it stays that way
  /// deliberately, since GuardrailDefinition is `const`-constructible and
  /// used in `const` guardrail lists throughout consumers; giving its
  /// constructor a runtime-throwing body would force every one of those
  /// call sites off `const`. This is the real runtime trust boundary
  /// instead — a guardrail with neither bound set (e.g. one assembled
  /// from a remote-config payload missing both fields) is caught HERE,
  /// unconditionally, in every build mode, rather than silently never
  /// firing [violatedBy] at all.
  void registerGuardrail(String featureId, GuardrailDefinition guardrail) {
    if (guardrail.min == null && guardrail.max == null) {
      throw ArgumentError.value(
        guardrail,
        'guardrail',
        'needs at least a min or a max bound',
      );
    }
    (_guardrails[featureId] ??= []).add(guardrail);
  }

  /// Reports 1 [value] reading for [metricName] under [featureId]'s
  /// shadow-activation cohort. Checks every guardrail registered for
  /// [featureId] whose [GuardrailDefinition.metricName] matches — the
  /// FIRST violation found immediately force-kills [featureId] via
  /// [killSwitch] (see [RemoteKillSwitchController.forceKillLocally]) and
  /// stops checking; a value within every registered bound is a no-op
  /// (never touches [killSwitch] at all).
  ///
  /// Never affects any OTHER feature's guardrails or kill state — each
  /// [featureId] is checked and rolled back entirely independently.
  void reportMetric(String featureId, String metricName, double value) {
    final guardrails = _guardrails[featureId];
    if (guardrails == null) return;
    for (final guardrail in guardrails) {
      if (guardrail.metricName != metricName) continue;
      if (!guardrail.violatedBy(value)) continue;
      killSwitch.forceKillLocally(
        featureId,
        reason:
            'ShadowActivationController: guardrail "${guardrail.metricName}" '
            'violated (value=$value, min=${guardrail.min}, '
            'max=${guardrail.max})',
      );
      return;
    }
  }
}
