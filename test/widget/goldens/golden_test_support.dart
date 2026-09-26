import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Golden baselines are generated on Linux CI. Keep sub-pixel font rasterizer
/// variance from macOS below this threshold without hiding visual regressions.
GoldenFileComparator installGoldenTolerance(String testFile) {
  final previous = goldenFileComparator;
  goldenFileComparator = _TolerantGoldenFileComparator(
    Directory.current.uri.resolve('test/widget/goldens/$testFile'),
  );
  return previous;
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile);

  static const _maxDiffPercent = 0.01;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _maxDiffPercent;
    result.dispose();
    return passed;
  }
}
