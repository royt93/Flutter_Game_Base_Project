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

/// Chụp [boundaryKey] (phải là `RepaintBoundary`) thành PNG. Null nếu widget
/// chưa build (context null). Tách riêng khỏi [shareBoardImage] để test được
/// không cần chạm platform channel của share_plus.
Future<Uint8List?> captureBoardPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2.0,
}) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// Chụp bàn chơi rồi mở share sheet kèm [text]. No-op nếu chụp thất bại.
Future<void> shareBoardImage({
  required GlobalKey boundaryKey,
  required String text,
}) async {
  final png = await captureBoardPng(boundaryKey);
  if (png == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: const ['pop_star_blast.png'],
    ),
  );
}
