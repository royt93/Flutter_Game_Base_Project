import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quét mã nguồn tìm chuỗi hiển thị bị **hardcode** thay vì đi qua `.tr`.
///
/// Vì sao cần: `app_translations_test` và `i18n_debt_test` chỉ soi *bảng dịch*.
/// Một chuỗi không bao giờ tra bảng thì không test nào thấy. Hai ca đã lọt
/// đúng kiểu đó:
///
/// * `home_screen.dart` để `label: 'PLAY'` — nút to nhất màn hình, đứng nguyên
///   tiếng Anh ở cả 21 ngôn ngữ dù `play_now` đã có bản dịch đủ 22 locale.
/// * `neon_icon.dart` để `semanticLabel: 'Quay lại'` — TalkBack đọc **tiếng
///   Việt** cho người dùng mọi ngôn ngữ khác.
///
/// Phạm vi hẹp có chủ ý: chỉ bắt literal nằm ở vị trí chắc chắn hiển thị
/// (`Text(...)` và các tham số `label:`/`title:`/`hint:`/`semanticLabel:`...).
/// Quét rộng hơn sẽ đầy báo động giả và rồi bị tắt đi.
void main() {
  // Literal được phép: tên riêng của sản phẩm, không dịch ở bất kỳ ngôn ngữ nào.
  const allowed = <String>{'Pop Star Blast'};

  final param = RegExp(
    r"""(?:Text\(\s*|(?:label|title|hint|hintText|semanticLabel|tooltip)\s*:\s*)'([^'\\]{2,})'""",
  );
  final looksLikeKey = RegExp(r'^[a-z0-9_]+$');
  final hasWord = RegExp(r'[A-Za-z]{3}');

  test('không có chuỗi hiển thị hardcode trong lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // Bảng dịch chính là nơi chuỗi thô được phép sống.
      if (f.path.endsWith('app_translations.dart')) continue;

      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in param.allMatches(lines[i])) {
          final s = m.group(1)!;
          if (!hasWord.hasMatch(s)) continue; // số/ký hiệu
          if (looksLikeKey.hasMatch(s)) continue; // chính là key i18n
          if (allowed.contains(s)) continue;
          offenders.add('${f.path}:${i + 1}  "$s"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'chuỗi hiển thị phải qua `.tr`; thêm key vào AppTranslations rồi '
          'dùng nó:\n${offenders.join('\n')}',
    );
  });
}
