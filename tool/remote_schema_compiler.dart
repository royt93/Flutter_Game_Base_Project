// Remote Schema Compiler CLI (FEAT-81) — compiles a declarative remote
// content pack schema (JSON) into a self-contained, immutable Dart model
// class. No Flutter dependency in the compiler itself, so this runs
// headless via `dart run`, same pattern as `tool/dependency_sbom_check.dart`.
//
// Schema JSON shape:
//   {
//     "packName": "shopCatalog",
//     "versions": [
//       {"version": 1, "fields": [{"name": "title", "type": "string"}, ...]}
//     ]
//   }
//
// Usage:
//   dart run tool/remote_schema_compiler.dart --schema=<path.json>
//     --outDir=<dir> [--fixture=<path.json> --secret=<value>]
//
// `--fixture`/`--secret` are optional: when given, the fixture envelope
// (as produced by `save_integrity.dart`'s `signExport`-style signing) is
// verified against the compiled schema BEFORE anything is written — an
// invalid signature or too-new schemaVersion aborts the whole run with
// exit code 1, never generating a model from unverified/unsafe content.

import 'dart:convert';
import 'dart:io';

import 'package:roy_casual_kit/core/utils/remote_schema_compiler.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

RemoteSchemaFieldType _typeByName(String name) => switch (name) {
  'string' => RemoteSchemaFieldType.string,
  'int' => RemoteSchemaFieldType.int,
  'double' => RemoteSchemaFieldType.double,
  'boolean' || 'bool' => RemoteSchemaFieldType.boolean,
  _ => throw RemoteSchemaCompilerException('unknown field type "$name"'),
};

RemoteSchemaDef _parseSchema(Map<String, Object?> json) {
  final packName = json['packName'];
  if (packName is! String) {
    throw const RemoteSchemaCompilerException('missing/invalid "packName"');
  }
  final rawVersions = json['versions'];
  if (rawVersions is! List) {
    throw const RemoteSchemaCompilerException('missing/invalid "versions"');
  }
  final versions = rawVersions.map((rawVersion) {
    if (rawVersion is! Map) {
      throw const RemoteSchemaCompilerException('each version must be an object');
    }
    final version = rawVersion['version'];
    if (version is! int) {
      throw const RemoteSchemaCompilerException('each version needs an int "version"');
    }
    final rawFields = rawVersion['fields'];
    if (rawFields is! List) {
      throw const RemoteSchemaCompilerException('each version needs a "fields" list');
    }
    final fields = rawFields.map((rawField) {
      if (rawField is! Map) {
        throw const RemoteSchemaCompilerException('each field must be an object');
      }
      final name = rawField['name'];
      final type = rawField['type'];
      if (name is! String || type is! String) {
        throw const RemoteSchemaCompilerException(
          'each field needs a string "name" and "type"',
        );
      }
      return RemoteSchemaField(name: name, type: _typeByName(type));
    }).toList();
    return RemoteSchemaVersion(version: version, fields: fields);
  }).toList();
  return RemoteSchemaDef(packName: packName, versions: versions);
}

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq == -1) continue;
    options[arg.substring(2, eq)] = arg.substring(eq + 1);
  }

  final schemaPath = options['schema'];
  final outDir = options['outDir'];
  if (schemaPath == null || outDir == null) {
    stderr.writeln(
      'Usage: dart run tool/remote_schema_compiler.dart --schema=<path.json> '
      '--outDir=<dir> [--fixture=<path.json> --secret=<value>]',
    );
    exitCode = 64;
    return;
  }

  final RemoteSchemaDef schema;
  try {
    final decoded = jsonDecode(File(schemaPath).readAsStringSync());
    schema = _parseSchema(Map<String, Object?>.from(decoded as Map));
  } on RemoteSchemaCompilerException catch (e) {
    stderr.writeln('Schema invalid: ${e.message}');
    exitCode = 1;
    return;
  }

  final fixturePath = options['fixture'];
  final secret = options['secret'];
  if (fixturePath != null) {
    if (secret == null) {
      stderr.writeln('--fixture requires --secret');
      exitCode = 64;
      return;
    }
    final envelope = Map<String, Object?>.from(
      jsonDecode(File(fixturePath).readAsStringSync()) as Map,
    );
    final result = verifySignedFixture(schema, envelope, secret);
    if (result case SdkFailure(:final message)) {
      stderr.writeln('Fixture rejected: $message');
      exitCode = 1;
      return;
    }
    stdout.writeln('Fixture verified OK against schema v${schema.current.version}.');
  }

  final source = generateModelSource(schema);
  final className = '${schema.packName[0].toUpperCase()}${schema.packName.substring(1)}Content';
  final outPath = '$outDir/${_snakeCase(schema.packName)}_content.g.dart';
  Directory(outDir).createSync(recursive: true);
  File(outPath).writeAsStringSync(source);
  stdout.writeln('Wrote $outPath ($className, schema v${schema.current.version}).');
}

String _snakeCase(String input) => input.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m.group(0)!.toLowerCase()}',
);
