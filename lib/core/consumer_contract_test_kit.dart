import 'kit_bootstrap.dart';
import 'storage_service.dart';

/// Deterministic, vendor-neutral fixture for consumer contract tests.
///
/// It uses the in-memory [StorageService] fallback and never touches network,
/// audio, notifications or a platform channel. Consumers can pass the
/// returned config directly to [RoyCasualKit.initialize].
class RoyCasualKitTestFixture {
  RoyCasualKitTestFixture({
    this.modules = const {
      RoyCasualKitModule.storage,
      RoyCasualKitModule.locale,
    },
  });

  final Set<RoyCasualKitModule> modules;
  final StorageService storage = StorageService(null);

  RoyCasualKitConfig get config => RoyCasualKitConfig(
    modules: modules,
    storageOverride: storage,
    permanent: false,
  );
}

/// Result of the standard consumer bootstrap contract checks.
class RoyCasualKitContractReport {
  const RoyCasualKitContractReport({required this.checks});

  final Map<String, bool> checks;
  bool get passed => checks.values.every((value) => value);
  List<String> get failures => [
    for (final entry in checks.entries)
      if (!entry.value) entry.key,
  ];
}

/// Reusable assertions expressed as a plain Dart report so consumers can use
/// it from any test runner and turn failures into their preferred matcher.
class RoyCasualKitContractTestKit {
  RoyCasualKitContractTestKit._();

  static Future<RoyCasualKitContractReport> verifyBootstrap({
    required Future<RoyCasualKitResult> Function() initialize,
    required Set<RoyCasualKitModule> expectedModules,
  }) async {
    final first = await initialize();
    final second = await initialize();
    return RoyCasualKitContractReport(
      checks: {
        'bootstrap has no module errors': first.errors.isEmpty,
        'all expected modules registered': first.registeredModules.containsAll(
          expectedModules,
        ),
        'bootstrap status is initialized':
            first.status == RoyCasualKitStatus.initialized,
        'repeated bootstrap preserves module registry':
            second.registeredModules.length == first.registeredModules.length &&
            second.registeredModules.containsAll(first.registeredModules),
      },
    );
  }
}
