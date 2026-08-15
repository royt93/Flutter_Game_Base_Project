import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quét mã nguồn tìm chỗ dùng hướng **vật lý** (left/right) thay vì hướng
/// **đọc** (start/end) — những chỗ đó không tự lật ở tiếng Ả Rập.
///
/// Vì sao cần: `long_locale_overflow_test.dart` chạy cả `ar_SA` và xanh sạch,
/// nhưng nó chỉ bắt được tràn khung. Lỗi RTL thường gặp hơn là **không lật**:
/// khoảng hở nằm sai bên, thanh tiến độ đầy ngược chiều. Không cái nào ném
/// exception, nên không test runtime nào thấy.
///
/// Đợt đầu chạy quét này tìm được 7 chỗ, trong đó nặng nhất là thanh tiến độ
/// mốc combo neo `Alignment.centerLeft` — ở RTL nó đầy từ trái sang phải
/// trong khi cả màn hình đọc từ phải sang trái.
///
/// **Giới hạn có chủ ý:** chỉ soi `lib/presentation`. Tầng logic/data thuần
/// không dựng widget nên không có hướng để sai.
void main() {
  /// `EdgeInsets.only(left:/right:)` và `Alignment.*Left/*Right` không lật.
  /// Bản `Directional` tương ứng thì có.
  final physicalPadding = RegExp(
    r'EdgeInsets\.only\([^)]*\b(?:left|right)\s*:',
  );
  final physicalAlign = RegExp(
    r'\bAlignment\.(?:centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b',
  );
  final ltrb = RegExp(r'EdgeInsets\.fromLTRB\(');

  /// `'<file>:<dòng>'` cố tình giữ hướng vật lý. Rỗng — chưa có ca nào cần.
  ///
  /// Thêm vào đây phải kèm lý do ngay trên dòng, kiểu "ảnh nền vẽ lệch trái
  /// theo thiết kế, không phải bố cục đọc".
  const allowed = <String>{};

  /// Bỏ phần comment cuối dòng trước khi so khớp.
  ///
  /// Bản đầu không làm thế và tự bắt chính mình: dòng chú thích giải thích
  /// "`Alignment.centerLeft` khiến thanh đầy ngược chiều" bị tính là vi phạm.
  String codeOnly(String line) {
    final i = line.indexOf('//');
    return i == -1 ? line : line.substring(0, i);
  }

  List<File> presentationFiles() => [
    for (final f in Directory('lib/presentation').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f,
  ];

  test('không dùng padding/alignment theo hướng vật lý', () {
    final offenders = <String>[];
    for (final f in presentationFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = codeOnly(lines[i]);
        final where = '${f.path}:${i + 1}';
        if (allowed.contains(where)) continue;
        if (physicalPadding.hasMatch(line)) {
          offenders.add(
            '$where  EdgeInsets.only(left/right) -> '
            'EdgeInsetsDirectional.only(start/end)',
          );
        }
        if (physicalAlign.hasMatch(line)) {
          offenders.add(
            '$where  Alignment.*Left/Right -> AlignmentDirectional.*Start/End',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'những chỗ này không lật ở tiếng Ả Rập:\n${offenders.join('\n')}',
    );
  });

  test('EdgeInsets.fromLTRB phải đối xứng ngang', () {
    // `fromLTRB` không lật được, nhưng nếu trái == phải thì lật hay không
    // cũng như nhau. Chỉ bắt trường hợp lệch.
    //
    // So sánh theo VĂN BẢN đối số chứ không tính giá trị: đủ dùng ở repo này
    // (đều là hằng `NeonTheme.s*` hoặc số) và không cần parse Dart.
    final offenders = <String>[];
    for (final f in presentationFiles()) {
      final text = f.readAsStringSync();
      for (final m in ltrb.allMatches(text)) {
        final open = m.end - 1;
        var depth = 0;
        var close = open;
        for (var i = open; i < text.length; i++) {
          if (text[i] == '(') depth++;
          if (text[i] == ')') {
            depth--;
            if (depth == 0) {
              close = i;
              break;
            }
          }
        }
        final args = text
            .substring(open + 1, close)
            .split(',')
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
        if (args.length != 4) continue;
        if (args[0] == args[2]) continue;
        final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
        offenders.add(
          '${f.path}:$line  fromLTRB(${args[0]}, .., ${args[2]}, ..) '
          'lệch trái/phải -> dùng EdgeInsetsDirectional.fromSTEB',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'padding lệch ngang không lật được ở RTL:\n${offenders.join('\n')}',
    );
  });

  test('quét có thật sự nhìn thấy file', () {
    // Không có ca này thì đường dẫn sai sẽ cho ra "0 vi phạm" và xanh giả.
    expect(presentationFiles().length, greaterThan(30));
  });

  test('regex bắt đúng mẫu vi phạm', () {
    // Cùng lý do: regex viết hỏng cũng cho ra 0 vi phạm.
    expect(physicalPadding.hasMatch('EdgeInsets.only(right: 4)'), isTrue);
    expect(
      physicalPadding.hasMatch('EdgeInsets.only(top: 4, bottom: 2)'),
      isFalse,
    );
    expect(
      physicalPadding.hasMatch('EdgeInsetsDirectional.only(end: 4)'),
      isFalse,
    );
    expect(physicalAlign.hasMatch('alignment: Alignment.centerLeft'), isTrue);
    expect(physicalAlign.hasMatch('alignment: Alignment.center'), isFalse);
    expect(
      physicalAlign.hasMatch(codeOnly('  // nói về Alignment.centerLeft')),
      isFalse,
      reason: 'comment không phải code',
    );
    expect(
      physicalAlign.hasMatch('alignment: AlignmentDirectional.centerStart'),
      isFalse,
    );
  });
}
