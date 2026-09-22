import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// BUG-59: `sharePositionOrigin` anchors the iPad share-sheet popover (iPad
/// uses a popover, not a bottom sheet like iPhone/Android) — omitting it
/// throws on iPadOS. Derived from [sharePositionContext]'s own `RenderBox`
/// (typically the button/card that triggered the share) when supplied;
/// `null` (the pre-fix default — no anchor) on platforms/callers that don't
/// need it, so this is purely additive, never a behavior change for an
/// existing call site that doesn't pass it.
Rect? _sharePositionOriginOf(BuildContext? sharePositionContext) {
  final box = sharePositionContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// One shared share pipeline used by every call site in the app — text-only
/// (e.g. inviting friends) or with a captured screenshot (e.g. a level
/// result). Don't create a separate share function/plugin call elsewhere.
///
/// Pass [sharePositionContext] (typically the widget that triggered the
/// share) so the share sheet has an anchor on iPad — see
/// [_sharePositionOriginOf].
Future<void> shareText(String text, {BuildContext? sharePositionContext}) {
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      sharePositionOrigin: _sharePositionOriginOf(sharePositionContext),
    ),
  );
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
  // BUG-59: the native Skia `ui.Picture` itself was never disposed — only
  // the `ui.Image`s it produces were (BUG-29's fix above). `toImage()`
  // rasterizes the recorded drawing ops into a separate `ui.Image`; the
  // `Picture` (the ops themselves) is a distinct native object that must be
  // disposed on its own, or it leaks every time a score/journey card with
  // overlay text is shared.
  try {
    return await picture.toImage(board.width, board.height);
  } finally {
    picture.dispose();
  }
}

/// Captures the board then opens the share sheet with [text]. No-op if the
/// capture fails.
///
/// Pass [sharePositionContext] for an iPad-safe popover anchor — see
/// [_sharePositionOriginOf].
Future<void> shareBoardImage({
  required GlobalKey boundaryKey,
  required String text,
  BuildContext? sharePositionContext,
}) async {
  // Computed before the `await` below — `sharePositionContext`'s widget may
  // unmount while `captureBoardPng` is running, making the context stale.
  final sharePositionOrigin = _sharePositionOriginOf(sharePositionContext);
  final png = await captureBoardPng(boundaryKey, overlayText: text);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_casual_kit.png'],
      sharePositionOrigin: sharePositionOrigin,
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
  BuildContext? sharePositionContext,
}) async {
  // Computed before the `await` below — see `shareBoardImage`'s comment.
  final sharePositionOrigin = _sharePositionOriginOf(sharePositionContext);
  final png = await captureBoardPng(boundaryKey, overlayText: levelText);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: levelText,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_casual_kit_score_card.png'],
      sharePositionOrigin: sharePositionOrigin,
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
  BuildContext? sharePositionContext,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_casual_kit_journey.png'],
      sharePositionOrigin: _sharePositionOriginOf(sharePositionContext),
    ),
  );
}
