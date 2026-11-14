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
  hardcodedColor,
  tapTargetSite,
  tapTargetSize,
  hardcodedString,
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

/// The 6 rules this audit actually runs — see this file's doc comment for
/// why only these (contrast/text-scale need real pixels, not source text).
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
    id: AuditRuleId.tapTargetSite,
    severity: AuditSeverity.warning,
    description:
        'GestureDetector/InkWell không có Semantics/MergeSemantics/semanticLabel trong vùng lân cận (8 dòng trước, 30 dòng sau): nút thiếu role/nhãn cho screen reader (ENH-106)',
    // Unused: _violatesRule evaluates this rule per site, not per file.
    triggerPattern: RegExp(r'GestureDetector\(|InkWell\('),
  ),
  AuditRule(
    id: AuditRuleId.tapTargetSize,
    severity: AuditSeverity.warning,
    description:
        'Tap target has an explicit local width/height below 48 logical pixels; source heuristic, not effective hit-area measurement (FEAT-202)',
    triggerPattern: _siteTrigger,
  ),
  AuditRule(
    id: AuditRuleId.hardcodedString,
    severity: AuditSeverity.info,
    description:
        'File có chuỗi tiếng Anh hiển thị cố định (Text(\'...\')/label:/title:/message:...) không qua tham số override hay .tr: consumer tiếng Việt thấy tiếng Anh (FEAT-203, mức info: nhiều chuỗi là mặc định hợp lệ của tham số có thể ghi đè)',
    triggerPattern: _hardcodedStringTrigger,
  ),
  AuditRule(
    id: AuditRuleId.hardcodedColor,
    severity: AuditSeverity.warning,
    description:
        'File dùng Colors.<tên>/Color(0x...) cố định thay vì token NeonTheme nên không đổi theo dark mode/reskin (ENH-104). Artwork cố ý: ghi vào baseline kèm lý do.',
    triggerPattern: RegExp(
      r'\bColors\.(?!transparent\b|white|black)[a-z]\w*|\bColor\(0x',
    ),
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

/// Per-site tap target rule (FEAT-202): every `GestureDetector(`/`InkWell(`
/// call needs a Semantics marker within [_siteLinesBefore] lines before or
/// [_siteLinesAfter] lines after it. Complements the per-file
/// [AuditRuleId.tapTargetSemantics], which one unrelated `Semantics(` anywhere
/// in the file satisfies. Heuristic: window-based, so a wrapper that
/// provides semantics from further away must be baselined with a reason.
const int _siteLinesBefore = 8;
const int _siteLinesAfter = 30;
const int _sizeSiteLinesBefore = 4;
const int _sizeSiteLinesAfter = 8;
final RegExp _siteTrigger = RegExp(r'GestureDetector\(|InkWell\(');
final RegExp _dimensionLiteral = RegExp(r'\b(width|height):\s*(\d+(?:\.\d+)?)\b');
final RegExp _sizeSuppression = RegExp(r'//\s*a11y-ok:\s*(\S.*)$');
final RegExp _siteMarker = RegExp(
  r'Semantics\(|MergeSemantics\(|semanticLabel|ExcludeSemantics\(',
);

/// Number of tap-target sites in [content] with no semantics marker nearby.
int _countUnlabeledTapSites(String content) {
  final lines = _stripLineComments(content).split('\n');
  var count = 0;
  for (var i = 0; i < lines.length; i++) {
    if (!_siteTrigger.hasMatch(lines[i])) continue;
    final from = i - _siteLinesBefore < 0 ? 0 : i - _siteLinesBefore;
    final to = i + _siteLinesAfter > lines.length
        ? lines.length
        : i + _siteLinesAfter;
    if (!_siteMarker.hasMatch(lines.sublist(from, to).join('\n'))) count++;
  }
  return count;
}

bool _hasUndersizedTapDimension(String content) {
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (!_siteTrigger.hasMatch(lines[i])) continue;
    final from = i - _sizeSiteLinesBefore < 0 ? 0 : i - _sizeSiteLinesBefore;
    final to = i + _sizeSiteLinesAfter > lines.length
        ? lines.length
        : i + _sizeSiteLinesAfter;
    for (var j = from; j < to; j++) {
      final commentStart = lines[j].indexOf('//');
      final codeLine = commentStart == -1
          ? lines[j]
          : lines[j].substring(0, commentStart);
      final suppression = commentStart == -1
          ? null
          : _sizeSuppression.firstMatch(lines[j].substring(commentStart));
      for (final match in _dimensionLiteral.allMatches(codeLine)) {
        final value = double.parse(match.group(2)!);
        if (value >= 48) continue;
        if (suppression != null && suppression.group(1)!.trim().isNotEmpty) {
          continue;
        }
        return true;
      }
    }
  }
  return false;
}

/// User-visible English literal in widget code (FEAT-203): `Text('...')` or a
/// `label:`/`title:`/`message:`/`hintText:`/`semanticLabel:`/`tooltip:` argument
/// holding a plain string with at least 3 letters and no interpolation. A
/// bare lower-case identifier such as `level_up_skip` is a translation key
/// (resolved by `.tr`), not display text, and is skipped. Info
/// level only: many hits are legitimate English defaults of an overridable
/// parameter, so this counts and lists, it does not fail CI.
final RegExp _hardcodedStringTrigger = RegExp(
  r'''(?:Text\(\s*|label:\s*|title:\s*|message:\s*|hintText:\s*|semanticLabel:\s*|tooltip:\s*)(['"])(?![a-z0-9]+(?:_[a-z0-9]+)+\1)(?![a-z0-9_.]+\1)[^'"$\\]*[A-Za-z]{3,}[^'"$\\]*\1''',
);

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
  if (rule.id == AuditRuleId.tapTargetSite) {
    return _countUnlabeledTapSites(content) > 0;
  }
  if (rule.id == AuditRuleId.tapTargetSize) {
    return _hasUndersizedTapDimension(content);
  }
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
