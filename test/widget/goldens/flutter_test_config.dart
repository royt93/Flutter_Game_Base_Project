import 'dart:async';

/// ENH-117: leak tracking stays OFF for golden tests. `runGoldenMatrix` leaves
/// the last case's tree mounted so callers can still query it, which leak
/// tracking reports as not-disposed; unmounting inside the harness broke 76
/// golden tests once (see ENH-117, "Sự cố CI sau đợt 1").
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
