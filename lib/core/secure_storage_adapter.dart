import 'package:get/get.dart';

import 'utils/sdk_result.dart';

/// Platform-neutral secure-storage seam — the package pulls in no concrete
/// secure-storage SDK (no `flutter_secure_storage`, no Keychain/Keystore
/// wrapper); a consuming app registers its own adapter via
/// `Get.put<SecureStorageAdapter>(myAdapter, permanent: true)`, same
/// pattern as [PurchaseSeam]/[CloudSaveProvider]/[AnalyticsProvider]. A
/// typical real implementation just forwards these 4 methods to
/// `flutter_secure_storage`'s `FlutterSecureStorage` (Keychain on iOS,
/// EncryptedSharedPreferences/Keystore on Android) — this seam doesn't
/// pick that dependency for you.
///
/// This is the raw adapter contract an implementation fulfills — plain
/// `Future`s, throwing on failure (mirrors [PurchaseSeam]'s shape). Call
/// sites should go through [SecureStorage] instead of this interface
/// directly: it adds the typed [SdkResult] contract, input validation, and
/// — critically — the guarantee that a missing adapter fails clearly
/// rather than ever falling back to plain `StorageService`/
/// SharedPreferences for something meant to be secret.
abstract class SecureStorageAdapter {
  /// Returns the stored value for [key], or `null` if nothing is stored.
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Removes every value this adapter has stored.
  Future<void> clear();

  /// Null-safe accessor for call sites that may run before/without an
  /// adapter registered (mirrors [PurchaseSeam.maybe]). No `Noop*` default
  /// is provided on purpose — same reasoning as [PurchaseSeam]: silently
  /// no-op'ing a secret write would hide a real integration bug, and could
  /// look like "it worked" when nothing was actually persisted securely.
  static SecureStorageAdapter? get maybe =>
      Get.isRegistered<SecureStorageAdapter>()
      ? Get.find<SecureStorageAdapter>()
      : null;
}

/// The actual call surface for secure values — wraps [SecureStorageAdapter]
/// with the typed [SdkResult] contract, key validation, and a clear,
/// typed failure (never a silent fallback to regular storage) when no
/// adapter is registered.
class SecureStorage {
  SecureStorage._();

  /// Whether a [SecureStorageAdapter] is currently registered. A `true`
  /// here says nothing about whether the underlying platform keystore is
  /// actually unlocked/accessible right now — that can only be known by
  /// actually attempting an operation (see the `platform`-kind failures
  /// [read]/[write]/[delete]/[clear] can return).
  static bool get isAvailable => SecureStorageAdapter.maybe != null;

  static Future<SdkResult<String?>> read(String key) =>
      _run(key, (adapter) => adapter.read(key));

  static Future<SdkResult<bool>> write(String key, String value) =>
      _run(key, (adapter) async {
        await adapter.write(key, value);
        return true;
      });

  static Future<SdkResult<bool>> delete(String key) =>
      _run(key, (adapter) async {
        await adapter.delete(key);
        return true;
      });

  static Future<SdkResult<bool>> clear() =>
      _run(null, (adapter) async {
        await adapter.clear();
        return true;
      });

  static Future<SdkResult<T>> _run<T>(
    String? key,
    Future<T> Function(SecureStorageAdapter adapter) action,
  ) async {
    if (key != null && key.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Key must not be empty',
      );
    }
    final adapter = SecureStorageAdapter.maybe;
    if (adapter == null) {
      return const SdkFailure(
        kind: SdkErrorKind.platform,
        message: 'No SecureStorageAdapter registered',
      );
    }
    try {
      return SdkSuccess(await action(adapter));
    } catch (error, stack) {
      // Never interpolate the caller's value into this message — only the
      // key/kind are safe to surface, the value itself is exactly what
      // this seam exists to protect.
      return SdkFailure(
        kind: SdkErrorKind.platform,
        message: 'Secure storage operation failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }
}

/// In-memory [SecureStorageAdapter] for consumer contract tests — never
/// touches a real keystore/Keychain. Register it with
/// `Get.put<SecureStorageAdapter>(FakeSecureStorageAdapter())` in a test
/// that needs [SecureStorage] to actually succeed instead of failing with
/// "no adapter registered".
class FakeSecureStorageAdapter implements SecureStorageAdapter {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}
