---
id: BUG-74
title: "api_compatibility.dart's _currentChangelogSection dùng \\Z (không hợp lệ trong Dart RegExp) — không khớp mục CUỐI CÙNG trong CHANGELOG.md"
type: bug
priority: P4
effort: XS
source: "claude (phát hiện phụ trong lúc làm ENH-92, viết test cho api_compatibility.dart)"
---

## Vị trí
`tool/api_compatibility.dart`'s `_currentChangelogSection` (hàm private,
cuối file).

## Hiện trạng
```dart
String _currentChangelogSection(String changelog, String version) {
  final match = RegExp(
    '^## $version\\n(.*?)(?=^## |\\Z)',
    multiLine: true,
    dotAll: true,
  ).firstMatch(changelog);
  return match?.group(1) ?? '';
}
```
`\Z` được dùng trong lookahead để bắt "hết chuỗi" khi mục hiện tại là mục
CUỐI CÙNG trong `CHANGELOG.md` (không có mục `## ` nào tiếp theo). Nhưng
`\Z` KHÔNG phải escape hợp lệ trong cú pháp `RegExp` của Dart (theo chuẩn
ECMAScript/JS, không phải Perl/ICU nơi `\Z` mới có nghĩa "cuối chuỗi") —
verify độc lập bằng script tái hiện:
```dart
final changelog = '## 0.1.0\n### BREAKING\n- Removed Bar.\n';
RegExp('^## 0.1.0\\n(.*?)(?=^## |\\Z)', multiLine: true, dotAll: true)
    .firstMatch(changelog); // -> null (không khớp gì cả)
```

## Vì sao cần / Hậu quả
Khi mục hiện tại là mục CUỐI CÙNG trong `CHANGELOG.md` (không có mục cũ hơn
nào bên dưới), `_currentChangelogSection` luôn trả về chuỗi rỗng bất kể
nội dung thật của mục đó là gì — kể cả khi mục đó CÓ ghi "### BREAKING".
Hậu quả: gate `checkCompatibility()`'s 2 nhánh kiểm tra
(`removed.isNotEmpty && !section.contains('BREAKING')` và
`added.isNotEmpty && section.isEmpty`) sẽ LUÔN coi như KHÔNG có ghi chú
changelog hợp lệ trong trường hợp này — 1 xoá export hợp lệ có ghi chú
BREAKING đàng hoàng vẫn bị từ chối sai (throw), hoặc ngược lại 1 export
mới hợp lệ có ghi chú đầy đủ vẫn bị báo "thiếu changelog".

**Chưa từng gây hậu quả thật trong repo này** vì `CHANGELOG.md` thật luôn
có nhiều mục (mục mới nhất luôn được theo sau bởi mục cũ hơn), nên nhánh
"mục hiện tại là mục cuối" chưa bao giờ xảy ra trên dữ liệu thật — chỉ lộ
ra khi viết fixture test với đúng 1 mục changelog (xem `ENH-92`'s Quyết
định để biết fixture đã workaround bằng cách nào).

## Đề xuất
Sửa lookahead để không phụ thuộc `\Z`. Cách đơn giản nhất: bỏ `\Z` khỏi
lookahead, dựa vào việc `.*?` (non-greedy + `dotAll: true`) tự nhiên khớp
tới hết chuỗi khi không tìm được `(?=^## )` nào phía sau — tức đổi
lookahead alternation thành optional: dùng `(?:(?=^## )|$)` (khớp `^## `
HOẶC cuối chuỗi thật qua `$` với `multiLine: false` cho riêng phần này —
cẩn thận không để `multiLine: true` biến `$` thành "cuối MỖI dòng" thay vì
"cuối chuỗi"). Cách khác an toàn hơn: không dùng lookahead cuối chuỗi
trong regex — sau khi regex chỉ tìm `(?=^## )` (bỏ hẳn phần \Z), nếu không
match được đoạn `(.*?)(?=^## )` thì fallback dùng `substring` từ vị trí sau
header tới hết chuỗi (`changelog.substring(headerEnd)`).

## Acceptance criteria
- [x] `_currentChangelogSection` với changelog CHỈ 1 mục (mục hiện tại là
      mục cuối cùng, không có mục nào bên dưới) trả về đúng nội dung thật
      của mục đó (không còn rỗng sai).
- [x] Case cũ (mục hiện tại có mục khác bên dưới) vẫn hoạt động đúng như
      trước — không phá hành vi thật của repo (test qua fixture 2 mục vẫn
      pass y hệt).
- [x] Test end-to-end qua `checkCompatibility()` (hoặc CLI thật qua
      `--root` fixture) cho case "1 mục changelog duy nhất, có ghi
      BREAKING, xoá export" → PASS (không bị từ chối sai).
- [x] Test cho `test/tool/api_compatibility_check_test.dart`'s fixture
      (viết ở ENH-92, đang workaround bằng 2 mục) — cân nhắc thêm 1 test
      MỚI riêng dùng đúng 1 mục để chứng minh bug đã sửa, KHÔNG cần đổi
      các test cũ.

## Quyết định

**Implementation**: viết lại `_currentChangelogSection` không dùng lookahead
end-of-string nào cả — tìm dòng header `## $version` bằng `firstMatch`
thuần, cắt `substring` từ ngay sau header tới HOẶC header `## ` tiếp theo
(nếu có) HOẶC hết chuỗi (nếu không có, tức đây là mục cuối cùng) — thay vì
dựa vào 1 escape `\Z` không hợp lệ trong Dart RegExp.

**TDD**: viết test mới `BUG-74: changelog CHỈ 1 mục...` trước → `git stash`
riêng file lib → chạy: fail đúng lý do (`StateError: Breaking API removals
require a major version...` — code cũ coi section rỗng dù có "### BREAKING"
thật) → khôi phục, chạy lại — pass. Chạy lại TOÀN BỘ 6 test cũ của ENH-92
(fixture 2 mục) — vẫn pass nguyên vẹn, xác nhận không phá hành vi case cũ.

**Kết quả**:
- `flutter analyze` (root): sạch.
- `dart run tool/api_compatibility.dart check` thật trên repo thật (có
  nhiều mục CHANGELOG.md, không trúng nhánh bug): vẫn ra "unchanged" y hệt
  trước khi sửa — hành vi CLI thật không đổi.
- `flutter test --exclude-tags slow` (root): 2361 test, 19 fail — đúng
  khớp 19 golden-image baseline, KHÔNG có flaky phát sinh lần chạy này,
  không có regression.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- Không cần smoke test device (CLI tool test thuần).

**Tự chấm điểm: 9.5/10.** Bug thật, root cause rõ (escape không hợp lệ
trong Dart RegExp — đã verify bằng script độc lập trước khi sửa), fix
loại bỏ hoàn toàn phụ thuộc vào end-of-string anchor thay vì cố vá lại
cho đúng cú pháp Dart (rủi ro thấp hơn, dễ đọc hơn). TDD chứng minh chính
xác cả hành vi cũ SAI lẫn hành vi mới ĐÚNG, verify kỹ hành vi CLI thật
trên repo thật không đổi. Trừ 0.5 vì đây là bug ưu tiên rất thấp
(chưa từng gây hậu quả thật) — effort bỏ ra tương đối cho 1 vấn đề chưa
ai gặp phải trong thực tế.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-74-api-compatibility-changelog-section-z-anchor.md`
này trước khi làm. Đọc TOÀN BỘ `tool/api_compatibility.dart` (đặc biệt hàm
`_currentChangelogSection` và nơi gọi nó trong `checkCompatibility`) VÀ
`test/tool/api_compatibility_check_test.dart` (đã có sẵn từ ENH-92, dùng
đúng convention `--root` fixture + comment giải thích bug này ở đầu hàm
`writeChangelog`) trước khi sửa. Implement bằng TDD — viết test trước với
fixture CHANGELOG chỉ 1 mục, xác nhận fail đúng lý do (section rỗng sai)
trên code cũ, rồi mới sửa regex. Cẩn thận verify hành vi CLI thật KHÔNG
đổi trên repo thật (chạy `dart run tool/api_compatibility.dart check`
trước/sau, `CHANGELOG.md` thật có nhiều mục nên phải ra kết quả giống hệt
"unchanged").

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Verify `dart run tool/api_compatibility.dart check` thật trên repo thật
   vẫn ra "unchanged" (hành vi CLI không đổi).
5. Không cần smoke test device (CLI tool test thuần).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ
test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — đã verify độc lập bằng script Dart tái hiện trực tiếp (không suy
đoán), xác nhận `\Z` không match gì trong RegExp của Dart. Priority P4 (rất
thấp) vì chưa từng gây hậu quả thật trên dữ liệu CHANGELOG.md thật của
repo này — chỉ là 1 latent edge case. Không trùng task nào trong
`doc/task/done/`.
