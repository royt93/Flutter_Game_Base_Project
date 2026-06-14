import 'package:flutter/foundation.dart';

/// Log debug 'roy93~' — CHỈ in ở debug build, no-op (bị tree-shake) ở release.
/// Gom mọi vết debug trên máy về 1 chỗ, không gây nhiễu log bản phát hành.
void dlog(String msg) {
  if (kDebugMode) debugPrint('roy93~ $msg');
}
