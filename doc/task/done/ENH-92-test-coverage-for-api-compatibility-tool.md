---
id: ENH-92
title: "tool/api_compatibility.dart (chính CI gate chặn breaking-change) không có test riêng"
type: enhancement
priority: P3
effort: S
source: "claude (fork audit round 2, độc lập)"
---

## Vị trí
`tool/api_compatibility.dart` (109 dòng) — không có
`test/tool/api_compatibility_check_test.dart` hay bất kỳ file test nào
tương ứng.

## Hiện trạng
`.github/workflows/ci.yml` chạy `dart run tool/api_compatibility.dart
check` như GATE ĐẦU TIÊN, trước cả `flutter analyze` (dòng 27-28). Chính
CLAUDE.md ghi rõ tool này có giới hạn thật: chỉ quét regex khớp
class/enum/mixin/typedef/extension declaration và top-level function mà
identifier bắt đầu đúng đầu dòng — bỏ sót hàm có return type cùng dòng
(ví dụ `HapticPattern comboSyncHapticPattern(...)`), không đệ quy vào
barrel file (`common_widgets.dart`). Mọi file `tool/*.dart` KHÁC trong repo
đều có file test tương ứng (`asset_license_check.dart` có
`asset_license_check_test.dart`, `deprecation_check.dart` có
`deprecation_check_test.dart`, v.v.) — riêng file này thì không.

## Vì sao cần / Hậu quả
Đây là gate chặn breaking-change công khai của cả package — nếu chính logic
parse của gate này bị sửa sai (hoặc bị regress bởi 1 refactor vô tình), gate
có thể lặng lẽ ngừng phát hiện đúng 1 export bị xoá/đổi tên, và không ai
biết cho tới khi 1 breaking change thật đã lọt qua CI, publish lên
consumer, rồi mới phát hiện production.

## Đề xuất
Viết `test/tool/api_compatibility_check_test.dart` theo đúng convention các
file `test/tool/*_test.dart` khác (dùng fixture thư mục tạm hoặc gọi thẳng
hàm public của tool nếu có refactor sẵn cho testable). Cover tối thiểu:
export bị xoá → phát hiện đúng "removed"; export mới thêm → "additive";
không đổi gì → "unchanged"; và LÝ TƯỞNG (không bắt buộc nếu tốn quá nhiều
effort) — 1 test tái hiện đúng giới hạn regex đã biết (hàm có return type
cùng dòng bị bỏ sót) để ít nhất DOCUMENT rõ giới hạn này bằng test thay vì
chỉ bằng comment trong CLAUDE.md.

## Acceptance criteria
- [x] Test cho case "removed" (xoá 1 export) → tool báo đúng "removed",
      exit code khác 0 (hoặc theo đúng cơ chế tool hiện dùng để báo lỗi).
- [x] Test cho case "additive" (thêm 1 export mới) → tool báo đúng
      "additive".
- [x] Test cho case "unchanged" → tool báo đúng "unchanged".
- [x] Không cần sửa logic tool (trừ khi cần refactor nhỏ để testable được —
      nếu refactor, phải giữ nguyên hành vi CLI hiện tại, verify bằng cách
      chạy `dart run tool/api_compatibility.dart check` thật trên repo hiện
      tại trước/sau refactor, kết quả phải giống hệt nhau).

## Quyết định

**Refactor nhỏ cần thiết**: thêm flag `--root=` (mặc định `.`) vào
`tool/api_compatibility.dart`, đúng convention `--root` mà
`tool/asset_license_check.dart` đã thiết lập sẵn cho chính lý do này (test
trỏ vào fixture thay vì mutate repo thật). Mọi đường dẫn file
(`lib/roy_casual_kit.dart`, `tool/api_snapshot.json`, `CHANGELOG.md`,
`pubspec.yaml`) đổi từ hardcode sang `'$root/...'`. Verify hành vi CLI
KHÔNG đổi: chạy `dart run tool/api_compatibility.dart check` VÀ `snapshot`
thật trên repo thật trước/sau refactor — `check` ra "unchanged" cả 2 lần,
`snapshot` ghi ra file **byte-identical** (`git diff --stat
tool/api_snapshot.json` rỗng sau khi refactor + chạy lại).

**Test mới**: `test/tool/api_compatibility_check_test.dart` — 1 test trên
repo thật (case "unchanged" tự nhiên) + 5 test trên fixture `--root` (thêm
export mới/additive, xoá export thiếu ghi chú BREAKING/bị từ chối đúng exit
code khác 0, xoá export CÓ ghi chú BREAKING/breaking hợp lệ, unchanged trên
fixture, lệnh `snapshot` ghi đúng file fixture KHÔNG đụng snapshot thật).

**Phát hiện phụ quan trọng (KHÔNG sửa ở đây, ngoài phạm vi)**: trong lúc
xây fixture CHANGELOG chỉ có đúng 1 mục để test, phát hiện
`_currentChangelogSection`'s regex `(?=^## |\Z)` KHÔNG hoạt động đúng khi
mục hiện tại là mục CUỐI CÙNG trong file — `\Z` không phải escape hợp lệ
trong cú pháp RegExp của Dart (ECMAScript, không phải Perl/ICU), nên không
bao giờ khớp cuối chuỗi thật; với CHANGELOG chỉ 1 mục, section luôn trả về
rỗng bất kể nội dung thật. Đã verify độc lập bằng script tái hiện riêng
(`RegExp('^## $version\\n(.*?)(?=^## |\\Z)', ...).firstMatch(...)` trả
`null` với changelog 1 mục). Repo thật KHÔNG bao giờ trúng nhánh này (luôn
có nhiều mục changelog, mục hiện tại luôn được theo sau bởi mục cũ hơn) —
đây là bug tiềm ẩn thật nhưng chưa từng gây hậu quả thật. Đã tạo task riêng
`BUG-74` cho việc sửa gốc rễ (đúng scope ENH-92 là viết test, không phải
sửa gate logic) — fixture của test này workaround bằng cách luôn ghi 2 mục
CHANGELOG (mục hiện tại + 1 mục cũ bên dưới), có comment giải thích rõ lý
do ngay trong test.

**Kết quả**:
- `flutter analyze` (root): sạch.
- `dart run tool/api_compatibility.dart check`/`snapshot` thật: hành vi
  không đổi (unchanged cả trước/sau, file snapshot byte-identical).
- `flutter test --exclude-tags slow` (root): 2359 test, 20 fail — đúng
  khớp 19 golden-image baseline + `season_event_service_test.dart` ENH-71
  (flaky real-wall-clock đã biết trước, không liên quan thay đổi này).
  Không có regression.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- Không cần smoke test device (đây là CLI tool test thuần, không liên quan
  UI).

**Tự chấm điểm: 9.5/10.** Đúng scope (chỉ refactor tối thiểu để testable,
không sửa logic gate), verify kỹ hành vi CLI không đổi bằng byte-diff thật
chứ không chỉ "trông giống nhau", TDD chứng minh 5/6 test fail đúng lý do
trên code cũ (thiếu `--root`). Còn phát hiện thêm 1 bug thật ngoài dự tính
ban đầu và xử lý đúng cách (không tự ý mở rộng scope, tạo task riêng thay
vì sửa luôn). Trừ 0.5 vì chưa viết test riêng cho chính bug `\Z` mới phát
hiện — để dành cho BUG-74.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-92-test-coverage-for-api-compatibility-tool.md`
này trước khi làm. Đọc TOÀN BỘ `tool/api_compatibility.dart` (chỉ 109 dòng,
đọc hết) VÀ ít nhất 1 file `test/tool/*_test.dart` khác đã có sẵn (ví dụ
`test/tool/asset_license_check_test.dart`) để lấy đúng pattern viết test
CLI tool trong repo này (thường dùng fixture thư mục tạm qua `Directory.systemTemp`
hoặc tương tự — đọc kỹ để bắt chước đúng, không tự sáng tạo cách khác).
Việc chính là VIẾT TEST, không phải sửa logic tool — chỉ sửa tool nếu bắt
buộc phải refactor nhỏ để test được (ví dụ tách hàm main() thành hàm gọi
được từ test), và nếu làm vậy phải cực kỳ cẩn thận verify hành vi CLI không
đổi.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Chạy `dart run tool/api_compatibility.dart check` thật để xác nhận hành
   vi CLI không đổi nếu có refactor.
5. Không cần smoke test device (đây là CLI tool test, không liên quan UI).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ
test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — fork audit xác nhận qua so sánh trực tiếp: mọi file `tool/*.dart`
khác đều có test tương ứng, riêng file này (chính là gate CI chạy đầu tiên)
thì không, đã đọc `.github/workflows/ci.yml` xác nhận đúng vị trí trong
pipeline. Không trùng task nào trong `doc/task/done/`.
