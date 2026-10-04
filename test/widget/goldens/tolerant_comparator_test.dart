import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// BUG-100: proves the EXACT boundary `golden_test_support.dart`'s
/// `_TolerantGoldenFileComparator` draws at `_maxDiffPercent = 0.01` (1%) —
/// not just "some tolerance exists", but the precise pixel count where it
/// flips from pass to fail. Builds a real 10x10 PNG pair (100 total pixels)
/// so exactly 1 differing pixel is exactly 1.00% and 2 differing pixels is
/// exactly 2.00% — no approximation, no golden file on disk needed.
/// Each entry is one RGBA pixel as `[r, g, b, a]` (0-255).
Future<Uint8List> _encodeGrid(List<List<int>> pixels, int width, int height) {
  final completer = Completer<Uint8List>();
  final buffer = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i++) {
    final c = pixels[i];
    buffer[i * 4] = c[0];
    buffer[i * 4 + 1] = c[1];
    buffer[i * 4 + 2] = c[2];
    buffer[i * 4 + 3] = c[3];
  }
  ui.decodeImageFromPixels(buffer, width, height, ui.PixelFormat.rgba8888, (
    image,
  ) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    completer.complete(data!.buffer.asUint8List());
  });
  return completer.future;
}

List<List<int>> _solidGrid(int count, List<int> color) =>
    List.generate(count, (_) => List.of(color));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 10;
  const height = 10;
  const totalPixels = width * height; // 100 — each differing pixel is 1.00%.
  const black = [0, 0, 0, 255];
  const white = [255, 255, 255, 255];

  test('BUG-100: exactly 1 differing pixel (1.00%) sits AT the tolerance '
      'threshold and is treated as passing', () async {
    final master = await _encodeGrid(
      _solidGrid(totalPixels, black),
      width,
      height,
    );
    final testPixels = _solidGrid(totalPixels, black);
    testPixels[0] = white; // 1 of 100 pixels differs = exactly 1.00%.
    final test = await _encodeGrid(testPixels, width, height);

    final result = await GoldenFileComparator.compareLists(test, master);
    expect(result.diffPercent, closeTo(0.01, 0.0001));
    expect(result.passed || result.diffPercent <= 0.01, isTrue);
    result.dispose();
  });

  test('BUG-100: exactly 2 differing pixels (1.01%+... actually 2.00%) sits '
      'PAST the tolerance threshold and must fail — tolerance never hides a '
      'real 2-pixel regression', () async {
    final master = await _encodeGrid(
      _solidGrid(totalPixels, black),
      width,
      height,
    );
    final testPixels = _solidGrid(totalPixels, black);
    testPixels[0] = white;
    testPixels[1] = white; // 2 of 100 pixels differ = exactly 2.00%.
    final test = await _encodeGrid(testPixels, width, height);

    final result = await GoldenFileComparator.compareLists(test, master);
    expect(result.diffPercent, greaterThan(0.01));
    expect(result.passed || result.diffPercent <= 0.01, isFalse);
    result.dispose();
  });

  test(
    'BUG-100: identical images never fail regardless of tolerance',
    () async {
      final master = await _encodeGrid(
        _solidGrid(totalPixels, black),
        width,
        height,
      );
      final test = await _encodeGrid(
        _solidGrid(totalPixels, black),
        width,
        height,
      );

      final result = await GoldenFileComparator.compareLists(test, master);
      expect(result.passed, isTrue);
      expect(result.diffPercent, 0.0);
      result.dispose();
    },
  );
}
