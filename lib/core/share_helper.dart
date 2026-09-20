import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// One shared share pipeline used by every call site in the app — text-only
/// (e.g. inviting friends) or with a captured screenshot (e.g. a level
/// result). Don't create a separate share function/plugin call elsewhere.
Future<void> shareText(String text) {
  return SharePlus.instance.share(ShareParams(text: text));
}

/// Captures [boundaryKey] (must be a `RepaintBoundary`) as a PNG, overlaying
/// [overlayText] (if any) on a translucent bar at the bottom of the image —
/// so the image carries its own level/score/date info even if the recipient
/// only views/saves the picture, independent of the share caption. Returns
/// null if the widget hasn't built yet (context is null). Kept separate from
/// [shareBoardImage] so it's testable without touching share_plus's platform
/// channel.
Future<Uint8List?> captureBoardPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2.0,
  String? overlayText,
}) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return null;
  // BUG-29: type-check instead of force-casting — a key mismatched to a
  // non-RepaintBoundary widget (caller integration bug) now returns the
  // already-documented "no capture" result instead of an unhandled crash.
  final renderObject = ctx.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) return null;

  final board = await renderObject.toImage(pixelRatio: pixelRatio);
  // BUG-29: both `board` and (when an overlay is drawn) the new composited
  // image hold native pixel buffers that leak unless disposed — every
  // share (score card, journey card) previously leaked at least one.
  ui.Image? overlayImage;
  try {
    final image = (overlayText == null || overlayText.isEmpty)
        ? board
        : (overlayImage = await _withTextOverlay(
            board,
            overlayText,
            pixelRatio,
          ));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    board.dispose();
    overlayImage?.dispose();
  }
}

/// Draws [board] plus a translucent bar + white [text] at the bottom of the
/// image onto a new canvas.
Future<ui.Image> _withTextOverlay(
  ui.Image board,
  String text,
  double pixelRatio,
) async {
  final w = board.width.toDouble();
  final h = board.height.toDouble();
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 14 * pixelRatio,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w - 24 * pixelRatio);

  final barHeight = painter.height + 16 * pixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  canvas.drawImage(board, Offset.zero, Paint());
  canvas.drawRect(
    Rect.fromLTWH(0, h - barHeight, w, barHeight),
    Paint()..color = const Color(0xAA000000),
  );
  painter.paint(
    canvas,
    Offset(12 * pixelRatio, h - barHeight + 8 * pixelRatio),
  );
  final picture = recorder.endRecording();
  return picture.toImage(board.width, board.height);
}

/// Captures the board then opens the share sheet with [text]. No-op if the
/// capture fails.
Future<void> shareBoardImage({
  required GlobalKey boundaryKey,
  required String text,
}) async {
  final png = await captureBoardPng(boundaryKey, overlayText: text);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_casual_kit.png'],
    ),
  );
}

/// Captures a result widget (built temporarily in a hidden overlay right
/// before calling this) then opens the share sheet with [levelText] — same
/// pattern as [shareBoardImage] but with a separate file/caption because
/// this is a result card, not a board screenshot. Wire this to
/// `VictoryCardTemplate` (`presentation/widgets/common/victory_card_template.dart`)
/// — wrap it in a `RepaintBoundary(key: ...)` and pass that key here.
Future<void> shareScoreCard({
  required GlobalKey boundaryKey,
  required String levelText,
}) async {
  final png = await captureBoardPng(boundaryKey, overlayText: levelText);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: levelText,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_casual_kit_score_card.png'],
    ),
  );
}

/// Opens the share sheet with an already-captured journey card PNG.
///
/// Takes **bytes** rather than a `GlobalKey` like [shareScoreCard]: the
/// caller must tear down the hidden overlay right after capturing, so it
/// holds the bytes before reaching here. Still the same pipeline —
/// [captureBoardPng] — not a second image export path. Wire this to
/// `VictoryCardTemplate` (`presentation/widgets/common/victory_card_template.dart`)
/// the same way as [shareScoreCard], capturing the PNG via [captureBoardPng]
/// before calling this.
Future<void> shareJourneyCard({
  required Uint8List png,
  required String text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_casual_kit_journey.png'],
    ),
  );
}
