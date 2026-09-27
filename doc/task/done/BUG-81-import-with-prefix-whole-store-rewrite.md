---
id: BUG-81
title: "importWithPrefix rewrite toàn store, kill giữa chừng mất profile"
type: bug
priority: P0
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/storage_service.dart:430` `importWithPrefix`.

## Hiện trạng

`importWithPrefix` merge prefix-data với phần còn lại của store rồi gọi `importAll(merged)` → `_replaceAll` xóa-ghi TOÀN store chỉ để restore 1 prefix. Kill (OS low-memory, crash) giữa chừng mất cả profile ngoài prefix. Rollback trong `importAll` chỉ cứu Dart exception, không cứu killed process.

## Vì sao cần / Hậu quả

Restore 1 save slot không được phép đặt cược toàn bộ profile. Blast radius phải đúng bằng prefix đang restore.

## Đề xuất

Chỉ xóa/ghi đúng key có prefix: diff key prefix hiện tại vs `data`, remove key thừa + set từng key mới, mỗi key có try/catch, không qua `_replaceAll`. `removeAllWithPrefix` (dòng 391) đã làm đúng mẫu này — copy shape đó.

## Acceptance criteria

- [x] Kill-safe cho key ngoài prefix (key ngoài prefix không bao giờ bị xóa/ghi lại).
- [x] Key prefix thiếu trong `data` bị xóa (giữ ngữ nghĩa replace-scoped).
- [x] Key ngoài prefix nguyên vẹn sau restore.
- [x] Unit test kill-giữa (fake throw giữa chừng) + test round-trip `exportWithPrefix`/`importWithPrefix`.

## Quyết định

Bỏ hẳn đường qua `importAll`/`_replaceAll` — `importWithPrefix` giờ chỉ
set/remove đúng key thuộc `prefix` (cùng scoping `removeAllWithPrefix` đã
dùng), set trước remove sau (crash giữa chừng ưu tiên thừa dữ liệu hơn mất
dữ liệu). Outer method giữ không-`async` để 2 `ArgumentError` throw đồng bộ
y hệt code cũ.

**Sửa sau audit độc lập:** bản đầu bỏ luôn rollback-on-exception vì nghĩ
validate type trước đã đủ — nhưng `disaster_recovery_save_export.dart`'s
doc comment (dòng 101-109, 261-263) và message lỗi thật của `applyRestore`
("...slot này giữ nguyên dữ liệu cũ, không bị ghi dở dang") CAM KẾT với
người gọi rằng một exception thật giữa lúc ghi (không chỉ bad-value-type
validate trước) vẫn rollback được — cam kết này chỉ đúng khi
`importWithPrefix` dựa trên `importAll`'s whole-store snapshot. Bỏ hẳn
`importAll` mà không thay bằng gì thì contract đó bị phá âm thầm, không
test nào bắt được (chỉ có test bad-value-type, không có test throw-giữa-
platform-write). Đã thêm: chụp `exportWithPrefix(prefix)` TRƯỚC khi mutate
(scoped, không phải whole-store), bọc try/catch quanh vòng set/remove,
rollback đúng scoped-snapshot đó khi throw thật.

5 test mới trong `test/core/storage_service_test.dart` (group `ENH-77`):
`platformWrites` tăng đúng bằng số key trong `data` (không phụ thuộc key
ngoài prefix), blast-radius qua subclass `_RecordingStorageService` ghi log
mọi set/remove, thứ tự set-trước-remove-sau, round-trip đủ 4 kiểu giá trị,
và (sau audit) rollback đúng khi 1 platform write throw THẬT giữa loop
(subclass `_ThrowingAfterNStorageService`, khác test bad-value-type cũ vốn
throw trước khi chạm storage). 7 test cũ trong group + toàn bộ
`test/core/disaster_recovery_save_export_test.dart` (dùng
`_ThrowingStorageService` override ở mức public API) vẫn pass nguyên văn.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root và
`example/`. Không có UI-observable behavior nên không cần device smoke
test riêng cho bug này — verification qua unit test là đủ theo đúng bản
chất bug (thay đổi ở tầng storage nội bộ).

**Vòng audit thứ 2 (agent audit độc lập chuyên trách):** tìm thêm 1 defect
thật — 2 lời gọi `importWithPrefix` CÙNG prefix đồng thời (ví dụ 2 restore
chồng lấn) có thể interleave set/remove loop của nhau, tạo ra "save lai"
không khớp bất kỳ lần import nào. Đã sửa: `AsyncActionGuard` keyed theo
`prefix` (không phải global — 2 prefix khác nhau vẫn restore song song
bình thường), test mới mô phỏng 2 call chồng lấn bằng storage fake chặn
giữa write, xác nhận call thứ 2 chờ đúng, không dùng snapshot dở dang của
call thứ nhất.

**Refactor DRY sau review reuse/simplification:** switch 4-nhánh
`int/bool/double/String -> setInt/setBool/setDouble/setString` từng bị lặp
3 lần (`_importWithPrefixBody`, `_restorePrefixSnapshot`, `_replaceAll`) —
gộp thành `_writeTyped`. Discovery "key thuộc prefix nhưng không còn trong
map giữ lại" từng lặp 2 lần — gộp thành `_staleKeysUnder`. Giảm rủi ro một
type mới (ví dụ hỗ trợ `List<String>` sau này) chỉ được thêm ở 1/3 chỗ.

**Vòng audit line-diff cuối:** tìm thêm thứ tự rollback ngược với rule an
toàn chính — `_restorePrefixSnapshot` remove stale trước rồi mới set snapshot,
process kill giữa rollback có thể để MẤT dữ liệu cũ. Đã đảo rollback thành
set-before-remove y hệt apply path; test fake platform failure khóa cứng thứ
tự rollback này. Cũng khóa contract "rollback tự fail vẫn rethrow original
write error" (không mask root cause bằng rollback error).

Tự chấm: 9.5/10 (sau 3 vòng audit: vá rollback contract bị bỏ sót, vá race
2-import-cùng-prefix, refactor gộp trùng lặp, và sửa kill-safety ngay trong
rollback).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify `importWithPrefix` dòng 430 gọi `importAll(merged)`, `_replaceAll` xóa toàn bộ key rồi ghi lại, và `removeAllWithPrefix` dòng 391 đã xóa scoped đúng mẫu cần copy.
