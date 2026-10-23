import 'dart:convert';
import 'dart:io';

const _entrypointRelPath = 'lib/roy_casual_kit.dart';
const _snapshotRelPath = 'tool/api_snapshot.json';

/// [args] usage: `[snapshot|check] [--root=.]`. `--root` (default `.`,
/// the real repo when invoked normally) exists so
/// `test/tool/api_compatibility_check_test.dart` can point this at a
/// synthetic fixture directory instead of the real repo, same convention
/// `tool/asset_license_check.dart`'s own `--root` already established —
/// see that file's doc comment for why (exercising a
/// removed/added-export scenario without mutating real repo state).
Future<void> main(List<String> args) async {
  var root = '.';
  final positional = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else {
      positional.add(arg);
    }
  }
  if (positional.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/api_compatibility.dart [snapshot|check] [--root=.]',
    );
    exitCode = 64;
    return;
  }
  final command = positional.isEmpty ? 'check' : positional.single;
  switch (command) {
    case 'snapshot':
      await File('$root/$_snapshotRelPath').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(await collectApiSnapshot(root)),
      );
      stdout.writeln('Wrote $_snapshotRelPath');
    case 'check':
      await checkCompatibility(root);
    default:
      stderr.writeln(
        'Usage: dart run tool/api_compatibility.dart [snapshot|check] [--root=.]',
      );
      exitCode = 64;
  }
}

Future<Map<String, Object>> collectApiSnapshot(String root) async {
  final entry = await File('$root/$_entrypointRelPath').readAsString();
  final pubspecFile = File('$root/pubspec.yaml');
  final version = pubspecFile.existsSync()
      ? _readVersion(await pubspecFile.readAsString())
      : null;
  final exports = _parseExports(
    _entrypointRelPath.substring('lib/'.length),
    entry,
  ).map((edge) => edge.target).toSet().toList()..sort();
  final symbols = <String>[];
  final members = <String>[];
  // ponytail: regex scanner omits fields/getters; use analyzer for full Dart API coverage.
  final reachable = await _resolveReachableApi(root);
  for (final relative in reachable.keys.toList()..sort()) {
    final visible = reachable[relative];
    final source = await File('$root/lib/$relative').readAsString();
    symbols.addAll([
      for (final name in _declaredSymbols(source))
        if (visible == null || visible.contains(name)) '$relative:$name',
    ]);
    // 4. BUG-98: class/mixin MEMBER signatures (methods + constructors) —
    // top-level symbols above only record a class's own NAME, so deleting
    // or changing a method's params/return type (EconomyWallet.earn,
    // VersionedJsonStore.syncWith) previously reported "unchanged".
    members.addAll(
      _collectMembers(relative, source).where((member) {
        if (visible == null) return true;
        final owner = member.substring(relative.length + 1).split('.').first;
        return visible.contains(owner);
      }),
    );
  }
  symbols.sort();
  members.sort();
  final result = <String, Object>{
    'version': ?version,
    'entrypoint': _entrypointRelPath,
    'exports': exports,
    'symbols': symbols,
    'members': members,
  };
  return result;
}

/// Top-level declared names in [source] — the same three regex passes
/// `collectApiSnapshot` always used, unchanged, just extracted so the
/// transitive resolver below can reuse them.
Set<String> _declaredSymbols(String source) {
  final names = <String>{};
  // 1. Classes, enums, mixins, typedefs, extensions, extension types with modern Dart modifiers
  for (final match in RegExp(
    r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*(?:class|enum|mixin|typedef|extension(?:\s+type)?)\s+([A-Za-z][A-Za-z0-9_]*)',
    multiLine: true,
  ).allMatches(source)) {
    names.add(match.group(1)!);
  }
  // 2. Top-level const / final
  for (final match in RegExp(
    r'^(?:const|final)\s+(?:[A-Za-z0-9_<>,?\s]+\s+)?([A-Za-z][A-Za-z0-9_]*)\s*=',
    multiLine: true,
  ).allMatches(source)) {
    names.add(match.group(1)!);
  }
  // 3. Top-level typed functions (block or arrow) and getters/setters
  for (final match in RegExp(
    r'^(?:(?:external\s+)?(?:(?:void|[A-Za-z][A-Za-z0-9_<>.,?]*)\s+)?(?:(get|set)\s+)?([A-Za-z][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*(?:\([^;]*?\)|(?<=\bget\s+[A-Za-z][A-Za-z0-9_]*))\s*(?:async\*?|sync\*?)?\s*(?:=>|\{))',
    multiLine: true,
  ).allMatches(source)) {
    final name = match.group(2)!;
    const reserved = {
      'if',
      'for',
      'while',
      'switch',
      'return',
      'class',
      'enum',
      'mixin',
      'typedef',
      'extension',
      'const',
      'final',
      'assert',
    };
    if (!reserved.contains(name)) names.add(name);
  }
  return names;
}

// ---- Wave 30: transitive local export resolution ----

final _exportDirective = RegExp(
  r'''^\s*export\s+(?:'([^']*)'|"([^"]*)")\s*([^;]*);$''',
);

class _ExportEdge {
  _ExportEdge(this.target, this.show, this.hide);
  final String target;
  final Set<String>? show;
  final Set<String> hide;
}

/// Parses `export` directives of [source] (lib-relative [from]), rejecting
/// forms this local scanner cannot resolve rather than silently dropping
/// public API: package:/dart: URIs, conditional exports, `part` files and
/// anything else that is not a plain relative path with optional
/// show/hide. Comment lines are ignored.
List<_ExportEdge> _parseExports(String from, String source) {
  final code = source.replaceAllMapped(
    RegExp(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|//[^\n]*|/\*[\s\S]*?\*/'''),
    (match) => match[0]!.startsWith('/')
        ? match[0]!.replaceAll(RegExp(r'[^\n]'), ' ')
        : match[0]!,
  );
  if (RegExp(r'^\s*part\s+', multiLine: true).hasMatch(code)) {
    throw StateError('Unsupported part directive in lib/$from');
  }
  final directives = RegExp(
    r'''^\s*export\s+(?:'[^']*'|"[^"]*")[^;]*(?:;|$)''',
    multiLine: true,
  ).allMatches(code);
  final edges = <_ExportEdge>[];
  for (final directive in directives) {
    final match = _exportDirective.firstMatch(directive.group(0)!);
    if (match == null) {
      throw StateError('Unsupported export syntax in lib/$from');
    }
    final uri = match.group(1) ?? match.group(2)!;
    if (uri.isEmpty ||
        uri.contains(RegExp(r'[:\\?#%]')) ||
        uri.startsWith('/')) {
      throw StateError('Unsupported export URI "$uri" in lib/$from');
    }
    final tail = match.group(3)!.trim();
    Set<String>? show;
    final hide = <String>{};
    var remaining = tail;
    final combinator = RegExp(
      r'^(show|hide)\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)(?=\s+(?:show|hide)\b|$)',
    );
    while (remaining.isNotEmpty) {
      final parsed = combinator.firstMatch(remaining);
      if (parsed == null) {
        throw StateError('Unsupported export clause "$tail" in lib/$from');
      }
      final names = parsed.group(2)!.split(',').map((n) => n.trim()).toSet();
      if (parsed.group(1) == 'show') {
        show = show == null ? names : show.intersection(names);
      } else {
        hide.addAll(names);
      }
      remaining = remaining.substring(parsed.end).trim();
    }
    edges.add(_ExportEdge(_resolveLibPath(from, uri), show, hide));
  }
  return edges;
}

String _resolveLibPath(String from, String uri) {
  final parts = from.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isEmpty) {
        throw StateError('Export "$uri" in lib/$from escapes lib/');
      }
      parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  return parts.join('/');
}

// Preserve defining-file identity while propagating filtered names through cycles.
Future<Map<String, Set<String>?>> _resolveReachableApi(String root) async {
  final sources = <String, String>{};
  final edges = <String, List<_ExportEdge>>{};
  final pending = <String>[_entrypointRelPath.substring('lib/'.length)];
  while (pending.isNotEmpty) {
    final file = pending.removeLast();
    if (sources.containsKey(file)) continue;
    final f = File('$root/lib/$file');
    if (!f.existsSync()) {
      throw StateError('Exported file lib/$file does not exist');
    }
    final source = await f.readAsString();
    sources[file] = source;
    edges[file] = _parseExports(file, source);
    pending.addAll(edges[file]!.map((e) => e.target));
  }

  // names each file exposes to its importers (own declarations + filtered
  // re-exports), iterated until nothing changes.
  final own = {
    for (final e in sources.entries) e.key: _declaredSymbols(e.value),
  };
  final exposed = {
    for (final e in own.entries) e.key: {...e.value},
  };
  var changed = true;
  while (changed) {
    changed = false;
    for (final file in sources.keys) {
      for (final edge in edges[file]!) {
        var names = exposed[edge.target]!;
        if (edge.show != null) {
          names = names.intersection(edge.show!);
        }
        names = names.difference(edge.hide);
        final before = exposed[file]!.length;
        exposed[file]!.addAll(names);
        if (exposed[file]!.length != before) changed = true;
      }
    }
  }

  // Push names admitted by the root down each export path. Unioning arrivals
  // preserves alternate unrestricted routes alongside narrower show/hide paths.
  final root0 = _entrypointRelPath.substring('lib/'.length);
  final admitted = <String, Set<String>>{
    root0: {...exposed[root0]!},
  };
  final visible = <String, Set<String>>{};
  var routesChanged = true;
  while (routesChanged) {
    routesChanged = false;
    for (final file in sources.keys) {
      final incoming = admitted[file];
      if (incoming == null) continue;
      if (file != root0) {
        final beforeVisible = visible
            .putIfAbsent(file, () => <String>{})
            .length;
        visible[file]!.addAll(own[file]!.intersection(incoming));
        if (visible[file]!.length != beforeVisible) routesChanged = true;
      }
      for (final edge in edges[file]!) {
        var names = exposed[edge.target]!.intersection(incoming);
        if (edge.show != null) names = names.intersection(edge.show!);
        names = names.difference(edge.hide);
        final target = admitted.putIfAbsent(edge.target, () => <String>{});
        final before = target.length;
        target.addAll(names);
        if (target.length != before) routesChanged = true;
      }
    }
  }
  return visible;
}

// ---- BUG-98: member-level signature extraction ----
//
// Regex/brace-depth based, deliberately NOT `package:analyzer` — keeps this
// tool dependency-light and fast, matching its existing convention (see the
// top-level regexes above). ponytail: scoped to methods + constructors only
// (getters/setters/plain fields skipped — no real breaking-change example
// needs them yet; add when one does). Does not account for braces inside
// string literals/comments, or a `{`/`}` collection literal appearing
// inside a constructor's initializer list before its real body brace —
// upgrade to `package:analyzer` if a real false positive from either
// surfaces; not built speculatively (YAGNI).
//
// The key correctness trick: once a member's own head is recognized, the
// scanner jumps PAST its entire body/tail in one step (via brace/paren
// matching) rather than descending into it character-by-character — so a
// bare call statement inside a method body (e.g. `add(circle);` inside
// `onLoad()`) is never visited by the scanner at all, and can't be
// mistaken for a sibling member declaration.
const _reservedMemberNames = {
  'if',
  'for',
  'while',
  'switch',
  'return',
  'do',
  'try',
  'catch',
  'assert',
};

final _classHeaderPattern = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface)\s+)*(?:class|mixin)\s+'
  r'([A-Za-z][A-Za-z0-9_]*)[^{;]*\{',
  multiLine: true,
);

final _memberParamsOpen = RegExp(r'\s*(?:<[^>]*>)?\s*\(');

final _annotationHead = RegExp(r'@[A-Za-z_][A-Za-z0-9_.]*');

List<String> _collectMembers(String relative, String source) {
  final members = <String>[];
  for (final classMatch in _classHeaderPattern.allMatches(source)) {
    final className = classMatch.group(1)!;
    final bodyStart = classMatch.end; // right after the class's own '{'
    final bodyEnd = _matchingBrace(source, classMatch.end - 1);
    if (bodyEnd == null) continue;
    final body = source.substring(bodyStart, bodyEnd);
    members.addAll(_collectClassMembers(relative, className, body));
  }
  return members;
}

List<String> _collectClassMembers(
  String relative,
  String className,
  String body,
) {
  final members = <String>[];
  final ctorPattern = RegExp(
    r'(?:const\s+|factory\s+)?' +
        RegExp.escape(className) +
        r'(?:\.([A-Za-z][A-Za-z0-9_]*))?',
  );
  final methodPattern = RegExp(
    r'(?:static\s+)?(?:((?:void|[A-Za-z][A-Za-z0-9_<>.,? \t]*))\s+)?'
    r'([A-Za-z][A-Za-z0-9_]*)',
  );

  var i = 0;
  while (i < body.length) {
    final afterTrivia = _skipTrivia(body, i);
    if (afterTrivia != i) {
      i = afterTrivia;
      continue;
    }
    if (i >= body.length) break;

    final ctorMatch = ctorPattern.matchAsPrefix(body, i);
    if (ctorMatch != null && ctorMatch.end > i) {
      final parenMatch = _memberParamsOpen.matchAsPrefix(body, ctorMatch.end);
      if (parenMatch != null) {
        final parenClose = _matchingParen(body, parenMatch.end - 1);
        if (parenClose != null) {
          final params = body.substring(parenMatch.end, parenClose);
          final ctorName = ctorMatch.group(1) ?? 'new';
          members.add('$relative:$className.$ctorName(${_normalize(params)})');
          i = _skipToNextTopLevelBoundary(body, parenClose + 1);
          continue;
        }
      }
    }

    final methodMatch = methodPattern.matchAsPrefix(body, i);
    if (methodMatch != null) {
      final returnType = methodMatch.group(1);
      final name = methodMatch.group(2)!;
      final parenMatch = _memberParamsOpen.matchAsPrefix(body, methodMatch.end);
      if (parenMatch != null &&
          name != className &&
          !_reservedMemberNames.contains(name) &&
          returnType != 'get' &&
          returnType != 'set') {
        final parenClose = _matchingParen(body, parenMatch.end - 1);
        if (parenClose != null) {
          final params = body.substring(parenMatch.end, parenClose);
          final sig = returnType == null
              ? '(${_normalize(params)})'
              : '(${_normalize(params)}): ${_normalize(returnType)}';
          members.add('$relative:$className.$name$sig');
          i = _skipToNextTopLevelBoundary(body, parenClose + 1);
          continue;
        }
      }
    }

    i = _skipToNextTopLevelBoundary(body, i);
  }
  return members;
}

/// Collapses whitespace only — deliberately keeps default values verbatim
/// (a default-value-only edit is flagged as a signature change too, the
/// safe-by-default direction for a gate whose whole job is to fail loudly
/// rather than silently pass a real break).
String _normalize(String raw) => raw.replaceAll(RegExp(r'\s+'), ' ').trim();

int _skipTrivia(String body, int start) {
  var i = start;
  while (i < body.length) {
    final c = body[i];
    if (c == ' ' || c == '\n' || c == '\t' || c == '\r') {
      i++;
      continue;
    }
    if (c == '/' && i + 1 < body.length && body[i + 1] == '/') {
      final nl = body.indexOf('\n', i);
      i = nl == -1 ? body.length : nl + 1;
      continue;
    }
    if (c == '/' && i + 1 < body.length && body[i + 1] == '*') {
      final end = body.indexOf('*/', i + 2);
      i = end == -1 ? body.length : end + 2;
      continue;
    }
    if (c == '@') {
      final annotation = _annotationHead.matchAsPrefix(body, i);
      if (annotation != null) {
        var j = annotation.end;
        if (j < body.length && body[j] == '(') {
          final close = _matchingParen(body, j);
          j = (close ?? body.length - 1) + 1;
        }
        i = j;
        continue;
      }
    }
    break;
  }
  return i;
}

/// From right after a member's param-list close paren, skips past whatever
/// comes next (constructor initializer list, `async`/`sync*` marker, an
/// arrow body, a block body, or an abstract/interface `;`) to the index
/// right after that member ends — WITHOUT the outer scan ever visiting the
/// characters inside a block body (see this section's top doc comment).
int _skipToNextTopLevelBoundary(String body, int start) {
  var parenDepth = 0;
  var i = start;
  while (i < body.length) {
    final c = body[i];
    if (c == '(' || c == '[') {
      parenDepth++;
    } else if (c == ')' || c == ']') {
      if (parenDepth > 0) parenDepth--;
    } else if (parenDepth == 0 && c == '{') {
      final close = _matchingBrace(body, i);
      return (close ?? body.length - 1) + 1;
    } else if (parenDepth == 0 && c == ';') {
      return i + 1;
    }
    i++;
  }
  return body.length;
}

int? _matchingBrace(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

int? _matchingParen(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

Future<void> checkCompatibility(String root) async {
  final snapshotFile = File('$root/$_snapshotRelPath');
  if (!snapshotFile.existsSync()) {
    throw StateError('Missing $_snapshotRelPath; run snapshot first.');
  }
  final baseline = jsonDecode(await snapshotFile.readAsString()) as Map;
  final baselineVersion = baseline['version'] as String?;
  final current = await collectApiSnapshot(root);
  final baselineExports = Set<String>.from(baseline['exports'] as List);
  final currentExports = Set<String>.from(current['exports'] as List);
  final baselineSymbols = Set<String>.from(baseline['symbols'] as List);
  final currentSymbols = Set<String>.from(current['symbols'] as List);
  // BUG-98: old snapshots have no 'members' key — same optional-field
  // pattern BUG-80 used for 'version', so they parse as empty, not crash.
  final baselineMembers = Set<String>.from(
    (baseline['members'] as List?) ?? const <String>[],
  );
  final currentMembers = Set<String>.from(current['members'] as List);
  final removed = {
    ...baselineExports.difference(currentExports),
    ...baselineSymbols.difference(currentSymbols),
    ...baselineMembers.difference(currentMembers),
  };
  final added = {
    ...currentExports.difference(baselineExports),
    ...currentSymbols.difference(baselineSymbols),
    ...currentMembers.difference(baselineMembers),
  };

  if (removed.isEmpty && added.isEmpty) {
    stdout.writeln('API compatibility: unchanged');
    return;
  }
  final changelog = await File('$root/CHANGELOG.md').readAsString();
  final version = _readVersion(await File('$root/pubspec.yaml').readAsString());
  final section = _currentChangelogSection(changelog, version);
  final isMajor = _isMajorBump(version, baselineVersion);
  if (removed.isNotEmpty && !isMajor && !section.contains('BREAKING')) {
    throw StateError(
      'Breaking API removals require a major version or BREAKING changelog entry: $removed',
    );
  }
  if (added.isNotEmpty && section.isEmpty) {
    throw StateError('API additions require a changelog section for $version.');
  }
  stdout.writeln(
    'API compatibility: ${removed.isEmpty ? 'additive' : 'breaking'}',
  );
  stdout.writeln('Added: $added');
  stdout.writeln('Removed: $removed');
}

String _readVersion(String yaml) => RegExp(
  r'^version:\s*([^\s+]+)',
  multiLine: true,
).firstMatch(yaml)!.group(1)!;

({int major, int minor, int patch})? _parseSemver(String version) {
  final clean = version.split('+').first.split('-').first;
  final parts = clean.split('.');
  if (parts.length != 3) return null;
  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = int.tryParse(parts[2]);
  if (major == null || minor == null || patch == null) return null;
  return (major: major, minor: minor, patch: patch);
}

bool _isMajorBump(String currentVersion, String? baselineVersion) {
  if (baselineVersion == null) return false;
  final current = _parseSemver(currentVersion);
  final baseline = _parseSemver(baselineVersion);
  if (current == null || baseline == null) return false;
  return current.major > baseline.major;
}

// BUG-74: previously used a lookahead `(?=^## |\Z)` to find the section's
// end — `\Z` isn't a valid escape in Dart's RegExp (ECMAScript syntax, not
// Perl/ICU where `\Z` means "end of string"), so it silently matched
// nothing, and the WHOLE regex failed to match at all whenever the current
// version's section was the LAST one in the file (no `## ` header after
// it to anchor on instead) — returning '' regardless of the section's
// real content. Finds the header via a plain `firstMatch`, then slices to
// either the next `## ` header or the end of the string — never relies on
// an end-of-string regex anchor at all.
String _currentChangelogSection(String changelog, String version) {
  final header = RegExp(
    '^## $version\$',
    multiLine: true,
  ).firstMatch(changelog);
  if (header == null) return '';
  final bodyStart = (header.end + 1).clamp(0, changelog.length);
  final rest = changelog.substring(bodyStart);
  final nextHeader = RegExp(r'^## ', multiLine: true).firstMatch(rest);
  return nextHeader == null ? rest : rest.substring(0, nextHeader.start);
}
