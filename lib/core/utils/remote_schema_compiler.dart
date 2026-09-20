/// Remote Schema Compiler (FEAT-81) — pure-Dart, no Flutter dependency, so
/// `tool/remote_schema_compiler.dart` can run as a genuine headless
/// `dart run` CLI (same constraint as `tool/accessibility_audit.dart`,
/// `tool/dependency_sbom.dart`).
///
/// Turns a declarative [RemoteSchemaDef] (a remote content pack's field
/// shape across its version history) into:
/// - [generateModelSource]: an immutable, value-equal Dart model class with
///   `fromJson`/`toJson` — the generated file has **zero import**, not even
///   on this package, so upgrading `roy_casual_kit` can never break a
///   previously-generated file (the compatibility policy this feature is
///   graded on).
/// - [buildMigrationRegistry]: wires the schema's version list into the
///   existing [SaveMigrationRegistry] (FEAT-37) — this compiler never
///   invents its own migration-chain validation, it only supplies the
///   version pairs; [SaveMigrationRegistry]'s own constructor still throws
///   [SaveMigrationException] on a broken/missing hop.
/// - [verifySignedFixture]: gates a "real" remote content fixture through
///   the exact same signature+version checks [RemoteContentPack] applies at
///   runtime (`save_integrity.dart`'s `verifyAndStrip`, reject-future-version)
///   — a compiler run never bakes a forged or too-new fixture into
///   generated migration-fixture data.
///
/// **Safety-first construction**: [RemoteSchemaDef]'s factory constructor
/// IS the validation gate — an invalid schema (duplicate/out-of-order
/// version, duplicate or non-identifier field name, empty field list) never
/// produces an instance, so no downstream step (codegen, migration wiring,
/// fixture verification) can ever run against a broken schema.
library;

import '../save_integrity.dart';
import 'safe_json.dart';
import 'save_migration_registry.dart';
import 'sdk_result.dart';

enum RemoteSchemaFieldType { string, int, double, boolean }

/// One field in one [RemoteSchemaVersion]'s shape.
class RemoteSchemaField {
  const RemoteSchemaField({required this.name, required this.type});

  final String name;
  final RemoteSchemaFieldType type;
}

/// One version's full field shape.
class RemoteSchemaVersion {
  const RemoteSchemaVersion({required this.version, required this.fields});

  final int version;
  final List<RemoteSchemaField> fields;
}

class RemoteSchemaCompilerException implements Exception {
  const RemoteSchemaCompilerException(this.message);
  final String message;
  @override
  String toString() => 'RemoteSchemaCompilerException: $message';
}

final _identifierPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Validated, immutable definition of one remote content pack's schema
/// across its version history. See library doc for the safety guarantee
/// its factory constructor provides.
class RemoteSchemaDef {
  factory RemoteSchemaDef({
    required String packName,
    required List<RemoteSchemaVersion> versions,
  }) {
    if (!_identifierPattern.hasMatch(packName)) {
      throw RemoteSchemaCompilerException(
        'packName "$packName" is not a valid Dart identifier',
      );
    }
    if (versions.isEmpty) {
      throw const RemoteSchemaCompilerException('versions must not be empty');
    }
    final sorted = [...versions]..sort((a, b) => a.version.compareTo(b.version));
    for (var i = 0; i < sorted.length; i++) {
      final version = sorted[i];
      if (version.version < 0) {
        throw RemoteSchemaCompilerException(
          'version ${version.version} must be non-negative',
        );
      }
      if (i > 0 && sorted[i - 1].version == version.version) {
        throw RemoteSchemaCompilerException(
          'duplicate version ${version.version}',
        );
      }
      if (version.fields.isEmpty) {
        throw RemoteSchemaCompilerException(
          'version ${version.version} has no fields',
        );
      }
      final seenFields = <String>{};
      for (final field in version.fields) {
        if (!_identifierPattern.hasMatch(field.name)) {
          throw RemoteSchemaCompilerException(
            'field "${field.name}" (version ${version.version}) is not a '
            'valid Dart identifier',
          );
        }
        if (!seenFields.add(field.name)) {
          throw RemoteSchemaCompilerException(
            'duplicate field "${field.name}" in version ${version.version}',
          );
        }
      }
    }
    return RemoteSchemaDef._(packName: packName, versions: List.unmodifiable(sorted));
  }

  const RemoteSchemaDef._({required this.packName, required this.versions});

  final String packName;

  /// Sorted ascending by [RemoteSchemaVersion.version]; always non-empty.
  final List<RemoteSchemaVersion> versions;

  /// The newest declared version — the shape [generateModelSource] and
  /// [buildMigrationRegistry]'s `currentVersion` target.
  RemoteSchemaVersion get current => versions.last;
}

String _upperFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _readerFor(RemoteSchemaFieldType type) => switch (type) {
  RemoteSchemaFieldType.string => '_asString',
  RemoteSchemaFieldType.int => '_asInt',
  RemoteSchemaFieldType.double => '_asDouble',
  RemoteSchemaFieldType.boolean => '_asBool',
};

String _dartTypeFor(RemoteSchemaFieldType type) => switch (type) {
  RemoteSchemaFieldType.string => 'String',
  RemoteSchemaFieldType.int => 'int',
  RemoteSchemaFieldType.double => 'double',
  RemoteSchemaFieldType.boolean => 'bool',
};

const Map<RemoteSchemaFieldType, String> _readerBody = {
  RemoteSchemaFieldType.string: "String _asString(Object? v) => v is String ? v : '';",
  RemoteSchemaFieldType.int:
      'int _asInt(Object? v) => v is int ? v : (v is double ? v.toInt() : 0);',
  RemoteSchemaFieldType.double:
      'double _asDouble(Object? v) => v is double ? v : (v is int ? v.toDouble() : 0.0);',
  RemoteSchemaFieldType.boolean: 'bool _asBool(Object? v) => v is bool ? v : false;',
};

/// Generates a self-contained (zero-import) immutable Dart model class for
/// [schema]'s [RemoteSchemaDef.current] version — value-equal (`==`/
/// `hashCode`), `fromJson`/`toJson`, never-throwing field readers (a
/// wrong-typed field falls back to a type-appropriate default, same
/// tolerant-parsing contract `lib/core/utils/safe_json.dart` follows,
/// re-implemented inline here instead of imported so the output has no
/// dependency on this package at all).
String generateModelSource(RemoteSchemaDef schema) {
  final className = '${_upperFirst(schema.packName)}Content';
  final fields = schema.current.fields;
  final usedReaders = {for (final f in fields) f.type}.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  final buffer = StringBuffer()
    ..writeln('// GENERATED BY tool/remote_schema_compiler.dart — DO NOT EDIT BY HAND.')
    ..writeln('// Schema: ${schema.packName} v${schema.current.version}')
    ..writeln()
    ..writeln('class $className {')
    ..writeln('  const $className({');
  for (final f in fields) {
    buffer.writeln('    required this.${f.name},');
  }
  buffer
    ..writeln('  });')
    ..writeln();
  for (final f in fields) {
    buffer.writeln('  final ${_dartTypeFor(f.type)} ${f.name};');
  }
  buffer
    ..writeln()
    ..writeln('  factory $className.fromJson(Map<String, Object?> json) => $className(');
  for (final f in fields) {
    buffer.writeln("    ${f.name}: ${_readerFor(f.type)}(json['${f.name}']),");
  }
  buffer
    ..writeln('  );')
    ..writeln()
    ..writeln('  Map<String, Object?> toJson() => {');
  for (final f in fields) {
    buffer.writeln("    '${f.name}': ${f.name},");
  }
  buffer
    ..writeln('  };')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  bool operator ==(Object other) =>')
    ..writeln('    other is $className &&');
  buffer.writeln(
    '${fields.map((f) => '    other.${f.name} == ${f.name}').join(' &&\n')};',
  );
  buffer
    ..writeln()
    ..writeln('  @override')
    ..writeln('  int get hashCode => Object.hashAll([')
    ..writeln('    ${fields.map((f) => f.name).join(', ')}')
    ..writeln('  ]);')
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      "  String toString() => '$className(' "
      "'${fields.map((f) => '${f.name}: \$${f.name}').join(', ')}' "
      "')';",
    )
    ..writeln('}');
  for (final type in usedReaders) {
    buffer
      ..writeln()
      ..writeln(_readerBody[type]);
  }
  return buffer.toString();
}

/// Wires [schema]'s version history into a [SaveMigrationRegistry] — one
/// [stepMigrations] entry per consecutive `(fromVersion, toVersion)` hop is
/// required (this compiler cannot safely synthesize field-transform logic
/// from a declarative schema alone). Throws [RemoteSchemaCompilerException]
/// if a hop's migrate function is missing; [SaveMigrationRegistry]'s own
/// constructor still re-validates the resulting chain.
SaveMigrationRegistry buildMigrationRegistry(
  RemoteSchemaDef schema, {
  required Map<int, Map<String, Object?> Function(Map<String, Object?> input)>
  stepMigrations,
}) {
  final steps = <SaveMigrationStep>[];
  for (var i = 0; i < schema.versions.length - 1; i++) {
    final from = schema.versions[i].version;
    final to = schema.versions[i + 1].version;
    final migrate = stepMigrations[from];
    if (migrate == null) {
      throw RemoteSchemaCompilerException(
        'missing migrate function for version $from -> $to',
      );
    }
    steps.add(SaveMigrationStep(fromVersion: from, toVersion: to, migrate: migrate));
  }
  return SaveMigrationRegistry(currentVersion: schema.current.version, steps: steps);
}

/// Verifies a fetched/authored [signedEnvelope] the same way
/// [RemoteContentPack] does at runtime: HMAC signature via
/// `save_integrity.dart`'s `verifyAndStrip`, then rejects a `schemaVersion`
/// newer than [schema]'s [RemoteSchemaDef.current] — a downgraded compiler
/// run must never bake content shaped for a future schema into generated
/// fixtures. Returns [SdkFailure] (never throws) on any problem so a CLI
/// caller can report it and refuse to generate anything from it.
SdkResult<Map<String, Object?>> verifySignedFixture(
  RemoteSchemaDef schema,
  Map<String, Object?> signedEnvelope,
  String secret,
) {
  final Map<String, Object?> verified;
  try {
    verified = verifyAndStrip(signedEnvelope, secret);
  } on FormatException catch (e) {
    return SdkFailure(
      kind: SdkErrorKind.validation,
      message: 'signature invalid: ${e.message}',
    );
  }
  final storedVersion = asIntOr(verified['schemaVersion'], 0);
  if (storedVersion > schema.current.version) {
    return SdkFailure(
      kind: SdkErrorKind.validation,
      message:
          'fixture schemaVersion $storedVersion is newer than compiled '
          'schema ${schema.current.version}',
    );
  }
  return SdkSuccess(verified);
}
