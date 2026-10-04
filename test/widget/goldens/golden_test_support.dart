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

  // BUG-100: this exact 1% boundary is proven (not just assumed) by
  // `tolerant_comparator_test.dart` — a 10x10 fixture where 1 differing
  // pixel (1.00%) passes and 2 differing pixels (2.00%) fails. 1% exists
  // ONLY to absorb macOS-vs-Linux-CI subpixel font rasterizer variance; it
  // is not a general "fuzzy match" knob. Never raise this to hide a real
  // rendering regression — if a golden legitimately needs a bigger diff
  // (a deliberate visual change), regenerate the golden file instead.
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
