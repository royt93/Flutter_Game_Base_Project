import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// F15/X6: 1 pipeline share dùng chung cho mọi nơi gọi trong app —
/// text-only (X6 mời bạn bè) hoặc kèm ảnh chụp bàn chơi (F15).
/// Không tạo hàm/plugin share riêng ở nơi khác.
Future<void> shareText(String text) {
  return SharePlus.instance.share(ShareParams(text: text));
}

/// Chụp [boundaryKey] (phải là `RepaintBoundary`) thành PNG, in đè
/// [overlayText] (nếu có) lên dải nền mờ ở đáy ảnh — để ảnh tự chứa thông tin
/// level/điểm/ngày kể cả khi người nhận chỉ xem/lưu ảnh, tách khỏi caption
/// chia sẻ. Null nếu widget chưa build (context null). Tách riêng khỏi
/// [shareBoardImage] để test được không cần chạm platform channel của
/// share_plus.
Future<Uint8List?> captureBoardPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2.0,
  String? overlayText,
}) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final board = await boundary.toImage(pixelRatio: pixelRatio);
  final image = (overlayText == null || overlayText.isEmpty)
      ? board
      : await _withTextOverlay(board, overlayText, pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// Vẽ [board] cùng dải nền mờ + [text] trắng ở đáy ảnh lên 1 canvas mới.
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

/// Chụp bàn chơi rồi mở share sheet kèm [text]. No-op nếu chụp thất bại.
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
      fileNameOverrides: const ['roy_base_game.png'],
    ),
  );
}

/// I57: chụp `ScoreCard` (dựng tạm trong overlay ẩn ngay trước khi gọi, xem
/// `GameScreenController.shareResultCard`) rồi mở share sheet kèm
/// [levelText] — cùng pattern với [shareBoardImage] nhưng tách file/caption
/// riêng vì đây là thẻ kết quả, không phải ảnh chụp board (F15).
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
      fileNameOverrides: const ['roy_base_game_score_card.png'],
    ),
  );
}

/// I87: mở share sheet với PNG thẻ hành trình đã chụp sẵn.
///
/// Nhận **bytes** chứ không nhận `GlobalKey` như [shareScoreCard]: bên gọi phải
/// gỡ overlay ẩn ngay sau khi chụp, nên nó cầm bytes trước khi tới đây. Vẫn là
/// cùng một pipeline — [captureBoardPng] — không phải đường xuất ảnh thứ hai.
Future<void> shareJourneyCard({
  required Uint8List png,
  required String text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['roy_base_game_journey.png'],
    ),
  );
}
