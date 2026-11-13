import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/economy_certificate.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/save_integrity.dart';
import 'package:roy_casual_kit/core/utils/remote_schema_compiler.dart';
import 'package:roy_casual_kit/core/utils/safe_json.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

/// Functions whose doc comment promises "never throws". Each entry feeds the
/// bad inputs that have broken such a promise before (an empty secret, a
/// tampered or empty envelope) and asserts no exception escapes. Add a new
/// entry when a function gains that doc promise (see CLAUDE.md, BUG-112).
void main() {
  final signed = signExport({'a': 1}, 'k');
  final badEnvelopes = <String, Map<String, Object?>>{
    'empty map': {},
    'tampered checksum': {'a': 1, checksumKey: 'nope'},
    'validly signed other data': signed,
  };
  const badSecrets = ['', 'wrong'];

  group('never-throws contracts survive bad secrets and envelopes', () {
    for (final secret in badSecrets) {
      for (final e in badEnvelopes.entries) {
        final label = 'secret="$secret", ${e.key}';
        test('EconomyCertificate.verify: $label', () {
          expect(
            () => EconomyCertificate.verify(e.value, secret),
            returnsNormally,
          );
        });
        test('ReplayCapsule.importSigned: $label', () {
          expect(
            () => ReplayCapsule.importSigned(e.value, secret),
            returnsNormally,
          );
        });
        test('verifySignedFixture: $label', () {
          final schema = RemoteSchemaDef(
            packName: 'pack',
            versions: const [
              RemoteSchemaVersion(
                version: 1,
                fields: [
                  RemoteSchemaField(
                    name: 'title',
                    type: RemoteSchemaFieldType.string,
                  ),
                ],
              ),
            ],
          );
          late SdkResult<Map<String, Object?>> result;
          expect(
            () => result = verifySignedFixture(schema, e.value, secret),
            returnsNormally,
          );
          expect(result, isA<SdkFailure>(), reason: label);
        });
      }
    }

    test('asIntOr tolerates any runtime type', () {
      for (final v in <Object?>[null, 'x', 1.5, true, [], {}]) {
        expect(() => asIntOr(v, 7), returnsNormally);
      }
    });
  });
}
