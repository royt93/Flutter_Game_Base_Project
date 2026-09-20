/// Pure, source-text-scanning accessibility audit — no Flutter
/// dependency, so it (and `tool/accessibility_audit_check.dart`, which
/// runs it against this package's own widgets) works as a genuinely
/// headless `dart run` CI check, no device/engine needed.
///
/// **Deliberately covers only what's checkable from source text alone**:
/// reduced-motion coverage, tap-target semantics coverage, and RTL
/// directional-safety. Contrast and text-scale coverage are NOT static-
/// scannable — they need real rendered pixels/layout, already covered by
/// `theme_contrast_validator.dart` (FEAT-68) and the golden matrix runner
/// (`test/support/golden_matrix.dart`, FEAT-69) respectively. This is a
/// deliberate scope cut, not an oversight — see this file's task
/// (`doc/task/done/FEAT-76-accessibility-audit-cli.md`) for the reasoning.
library;

enum AuditSeverity { info, warning, error }

enum AuditRuleId {
  reducedMotionCoverage,
  tapTargetSemantics,
  rtlDirectionalSafety,
}

/// One heuristic: if [triggerPattern] matches a file's source, the file
/// is expected to also match [requiredPattern] somewhere — if it
/// doesn't, that's a violation. `null` [requiredPattern] means any
/// [triggerPattern] match is itself always a violation (no "opt out"
/// companion pattern makes sense for that rule).
class AuditRule {
  const AuditRule({
    required this.id,
    required this.severity,
    required this.description,
    required this.triggerPattern,
    this.requiredPattern,
  });

  final AuditRuleId id;
  final AuditSeverity severity;
  final String description;
  final RegExp triggerPattern;
  final RegExp? requiredPattern;
}

/// The 3 rules this audit actually runs — see this file's doc comment for
/// why there are only 3, not 6.
final List<AuditRule> defaultAuditRules = [
  AuditRule(
    id: AuditRuleId.reducedMotionCoverage,
    severity: AuditSeverity.error,
    description:
        'File tạo AnimationController nhưng không tham chiếu NeonTheme.reducedMotion ở đâu cả',
    triggerPattern: RegExp(r'AnimationController\('),
    requiredPattern: RegExp('reducedMotion'),
  ),
  AuditRule(
    id: AuditRuleId.tapTargetSemantics,
    severity: AuditSeverity.warning,
    description:
        'File tạo GestureDetector/InkWell nhưng không có Semantics/semanticLabel/ExcludeSemantics nào',
    triggerPattern: RegExp(r'GestureDetector\(|InkWell\('),
    requiredPattern: RegExp('Semantics\\(|semanticLabel|ExcludeSemantics'),
  ),
  AuditRule(
    id: AuditRuleId.rtlDirectionalSafety,
    severity: AuditSeverity.warning,
    description:
        'File dùng EdgeInsets.only/Positioned với left:/right: literal thay vì start:/end: (EdgeInsetsDirectional/PositionedDirectional) an toàn theo hướng chữ',
    triggerPattern: RegExp(
      r'(EdgeInsets\.only\([^)]*\b(left|right):|Positioned\([^)]*\b(left|right):)',
    ),
  ),
];

/// Strips `//` line comments before matching — a doc comment showing
/// example code (`/// ...BadgeDot(top: -2, right: -2)`) is not itself a
/// layout call a rule should react to. Approximate (a `//` inside a
/// string literal would also get stripped), but that pattern doesn't
/// occur in this package's own widget source, and false-negative-by-
/// over-stripping is the safe failure direction for a lint tool (a
/// missed real violation is less harmful than a noisy one nobody trusts).
String _stripLineComments(String content) {
  final buffer = StringBuffer();
  for (final line in content.split('\n')) {
    final index = line.indexOf('//');
    buffer.writeln(index == -1 ? line : line.substring(0, index));
  }
  return buffer.toString();
}

bool _violatesRule(AuditRule rule, String content) {
  final code = _stripLineComments(content);
  if (!rule.triggerPattern.hasMatch(code)) return false;
  final required = rule.requiredPattern;
  if (required == null) return true;
  return !required.hasMatch(code);
}

/// One reported violation — [file] is whatever path the caller passed
/// in (typically repo-relative), not validated against the filesystem
/// by this pure function.
class AuditViolation {
  const AuditViolation({
    required this.file,
    required this.ruleId,
    required this.severity,
    required this.description,
  });

  final String file;
  final AuditRuleId ruleId;
  final AuditSeverity severity;
  final String description;

  @override
  String toString() =>
      '[${severity.name}] $file: ${ruleId.name} — $description';
}

/// One pre-approved exception — [reason] must be non-empty (enforced by
/// [AuditBaseline.fromJson], which silently drops any entry missing one
/// rather than let a reason-less suppression through).
class AuditSuppression {
  const AuditSuppression({
    required this.file,
    required this.ruleId,
    required this.reason,
  });

  final String file;
  final AuditRuleId ruleId;
  final String reason;
}

/// A parsed baseline file — every [AuditViolation] this baseline
/// [suppresses] is dropped from a scan's reported results, but never
/// silently: [AuditSuppression.reason] stays readable in the baseline
/// source file itself as the paper trail for "why this one's accepted".
class AuditBaseline {
  const AuditBaseline(this.suppressions);

  static const empty = AuditBaseline([]);

  final List<AuditSuppression> suppressions;

  /// Parses a JSON `List` of `{file, rule, reason}` maps — an entry
  /// missing any of the 3 fields, with an empty `reason`, or naming an
  /// unknown `rule` id is silently dropped (never throws): a malformed
  /// baseline should read as "fewer suppressions than intended," which
  /// makes the scan MORE strict, never a way to accidentally suppress
  /// more than the file actually says.
  static AuditBaseline fromJson(List<Object?> json) {
    final entries = <AuditSuppression>[];
    for (final raw in json) {
      if (raw is! Map) continue;
      final file = raw['file'];
      final rule = raw['rule'];
      final reason = raw['reason'];
      if (file is! String || rule is! String || reason is! String) continue;
      if (reason.trim().isEmpty) continue;
      AuditRuleId? ruleId;
      for (final id in AuditRuleId.values) {
        if (id.name == rule) {
          ruleId = id;
          break;
        }
      }
      if (ruleId == null) continue;
      entries.add(AuditSuppression(file: file, ruleId: ruleId, reason: reason));
    }
    return AuditBaseline(entries);
  }

  bool suppresses(AuditViolation violation) => suppressions.any(
    (s) => s.file == violation.file && s.ruleId == violation.ruleId,
  );
}

/// Scans [fileContents] (path → source text) against [rules], dropping
/// anything [baseline] suppresses. A file present in [fileContents] with
/// no violations contributes nothing — this function never reports
/// "clean" files, only actual findings.
List<AuditViolation> scanAccessibility({
  required Map<String, String> fileContents,
  List<AuditRule> rules = const [],
  AuditBaseline baseline = AuditBaseline.empty,
}) {
  final effectiveRules = rules.isEmpty ? defaultAuditRules : rules;
  final violations = <AuditViolation>[];
  for (final entry in fileContents.entries) {
    for (final rule in effectiveRules) {
      if (_violatesRule(rule, entry.value)) {
        final violation = AuditViolation(
          file: entry.key,
          ruleId: rule.id,
          severity: rule.severity,
          description: rule.description,
        );
        if (!baseline.suppresses(violation)) {
          violations.add(violation);
        }
      }
    }
  }
  return violations;
}
