---
id: ENH-78
title: "BackupRestorePanel: 'Working…' Semantics announcement hardcode, không caller-overridable (khác mọi string khác trong cùng file)"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/presentation/widgets/common/backup_restore_panel.dart`)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/common/backup_restore_panel.dart` (`BackupRestorePanel`, `_BackupRestorePanelState.build`).

## Hiện trạng
`BackupRestorePanel` đã có 7 param `String` caller-overridable với default tiếng Anh (`title`, `exportLabel`, `importLabel`, `confirmImportTitle`, `confirmImportMessage`, `exportSuccessMessage`, `importSuccessMessage` — dòng 43-73), đúng convention ENH-39 "package không tự làm i18n, caller truyền chuỗi đã dịch". Nhưng có đúng 1 chuỗi lọt lưới: dòng 232, `Semantics(liveRegion: true, label: 'Working…', ...)` — announcement cho screen reader trong lúc `_busy` (export/import đang chạy) — hardcode hoàn toàn, không có param nào override được.

## Vì sao cần / Hậu quả
Đây là 1 widget mà TẤT CẢ chuỗi khác (kể cả `_message` announcement cho success/error, dòng 240 `label: _message`) đều đã đi qua param `exportSuccessMessage`/`importSuccessMessage` do caller truyền — chỉ riêng chuỗi 'Working…' là ngoại lệ duy nhất còn hardcode tiếng Anh. Nếu 1 app dùng đúng convention ENH-39 (truyền tiếng Việt cho mọi param khác của panel này) thì trải nghiệm screen reader vẫn nghe "Working…" tiếng Anh giữa 2 câu tiếng Việt trước/sau — không nhất quán ngay trong 1 luồng thao tác.

## Đề xuất
Thêm 1 param optional, giữ NGUYÊN default hiện tại — không đổi hành vi cho caller chưa truyền:

```dart
const BackupRestorePanel({
  ...
  this.workingAnnouncement = 'Working…',
});

final String workingAnnouncement;
```

Dùng `workingAnnouncement` thay literal `'Working…'` ở dòng 232.

## Acceptance criteria
- [x] Không truyền `workingAnnouncement`: hành vi/announcement y hệt hiện tại (`'Working…'`).
- [x] Truyền `workingAnnouncement` tuỳ chỉnh: `Semantics.label` khi `_busy` dùng đúng chuỗi mới.
- [x] Không đổi hành vi `_Action`/`loading` (ENH-67)/`_status`/`_message` hiện có.
- [x] Không phá bất kỳ widget test nào trong `test/widget/common/backup_restore_panel_test.dart` (verify đường dẫn bằng `grep -rl BackupRestorePanel test/`).
- [x] Test: widget test verify cả 2 case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-78-backup-restore-panel-working-announcement.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/backup_restore_panel.dart` (đặc biệt constructor's 7 param `String` hiện có và `_BackupRestorePanelState.build`'s `Semantics` ở dòng ~230) trước khi sửa. Tìm test hiện có bằng `grep -rl BackupRestorePanel test/` trước khi viết test mới. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với 7 param `String` khác đã có trong chính widget này, không đổi hành vi mặc định, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao nhưng giá trị thấp — xác nhận qua đọc trực tiếp `backup_restore_panel.dart`: 7 param `String` khác đều overridable (dòng 43-73), chỉ `'Working…'` (dòng 232) hardcode. Đây là announcement CHỈ cho screen reader (không phải text hiển thị), nên tác động thực tế hẹp hơn ENH-75/ENH-39. Effort cực nhỏ (1 param), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`. Đã kiểm tra thêm 3 vị trí Semantics-only hardcode tương tự khác (`daily_login_calendar.dart:212`, `leaderboard_list.dart:81`, `shimmer_placeholder.dart:90`) nhưng KHÔNG chọn — mỗi widget đó chỉ có 1 chuỗi hardcode tổng thể (không phải ngoại lệ lọt lưới giữa nhiều chuỗi đã fix như trường hợp này), giá trị biên tế còn thấp hơn nữa.

## Quyết định

Đúng như đề xuất — thêm `workingAnnouncement` (default `'Working…'`, y hệt literal cũ), dùng thay cho `Semantics(label: 'Working…')` hardcode. Vá lỗ hổng cuối cùng — giờ TẤT CẢ chuỗi trong `BackupRestorePanel` đều caller-overridable.

**Test:** 2 test mới trong `test/widget/common/backup_restore_panel_test.dart` nhóm "ENH-78" — dùng `Completer` giữ export ở trạng thái `_busy` (đúng pattern test ENH-67 sẵn có), verify `Semantics.label` (tìm qua `liveRegion: true` predicate) đúng default và đúng giá trị tuỳ chỉnh.

**Kết quả:** root `flutter analyze` sạch (1 lint `no_leading_underscores_for_local_identifiers` phát sinh từ tên hàm test cục bộ `_liveRegion`, đã sửa thành `liveRegion` — không phải vấn đề logic), root `flutter test --exclude-tags slow` 1261/1261 pass. Không đụng `example/` (không bắt buộc).

**Tự chấm điểm: 9.5/10** — đúng convention 7 param `String` khác đã có sẵn trong chính widget này, test dùng đúng kỹ thuật `Completer` đã có tiền lệ (ENH-67), vá đúng lỗ hổng cuối cùng khiến mọi chuỗi trong panel đều overridable. Trừ 0.5 vì phải tự bắt 1 lint warning sau lần chạy analyze đầu (đặt tên biến cục bộ sai convention Dart).
