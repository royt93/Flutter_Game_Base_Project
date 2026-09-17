---
id: ENH-67
title: "BackupRestorePanel: vẫn tự hand-roll spinner/_busy riêng — chưa dùng CommonButton.loading dù chính nó là động lực tạo ra tính năng đó"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog audit — đọc trực tiếp `lib/presentation/widgets/common/backup_restore_panel.dart` và `doc/task/done/IDEA-53-common-button-loading-state.md`)
---

## Vị trí
Mở rộng/dọn dẹp — `lib/presentation/widgets/common/backup_restore_panel.dart` (`BackupRestorePanel`/`_BackupRestorePanelState`).

## Hiện trạng
`IDEA-53` (đã done) thêm `loading: bool` vào `CommonButton` — và chính task đó dùng ĐÚNG `BackupRestorePanel` này làm bằng chứng cho nhu cầu có thật: *"`backup_restore_panel.dart` đã tự tay dựng 1 pattern 'spinner cạnh nút, `_busy` tự quản trong State riêng' để giải quyết đúng nhu cầu này cho panel đó — nghĩa là nhu cầu có thật, nhưng không tái dùng được ở nơi khác vì nó không nằm trong chính `CommonButton`"*. Sau khi `CommonButton.loading` đã xong, đọc lại `backup_restore_panel.dart` xác nhận nó **VẪN CÒN NGUYÊN** cách làm cũ, chưa hề được refactor để dùng khả năng mới:

- Dòng 83: `bool get _busy => _status == _Status.working;`
- Dòng 173-177, 180-184: cả 2 `CommonButton` (Export/Import) chỉ dùng `onTap: _busy ? null : _handle...` để CHẶN TAP — không truyền `loading:` nào cả, nên không có spinner NÀO hiện trên chính nút.
- Dòng 206-239: 1 `Row` RIÊNG bên dưới 2 nút, tự vẽ `CircularProgressIndicator` (dòng 208-218) + text "Working…" khi `_busy` — đây chính là đoạn code hand-roll mà IDEA-53 định thay thế, vẫn còn nguyên.

## Vì sao cần / Hậu quả
Đây là ví dụ rõ ràng nhất của "thêm tính năng dùng chung nhưng quên quay lại dọn dẹp nơi đã tạo ra nhu cầu" — `CommonButton.loading` tồn tại chính vì panel này, nhưng panel vẫn duy trì 2 nguồn sự thật song song cho cùng 1 trạng thái "đang xử lý" (`_busy` điều khiển cả việc chặn tap CommonButton lẫn hiện spinner ở 1 chỗ khác) — dễ lệch nhau nếu sau này 1 trong 2 chỗ bị sửa mà quên sửa chỗ kia. Ngoài ra UX hiện tại: spinner nằm TÁCH RỜI khỏi nút đang xử lý (dưới cả 2 nút cùng lúc), không rõ nút NÀO đang chạy nếu người dùng không nhớ mình vừa bấm nút nào.

## Đề xuất
Refactor để 2 `CommonButton` tự hiện đúng trạng thái loading của MÌNH, thay vì dùng 1 spinner chung tách rời:

1. Đổi tracking từ `_Status` (chỉ biết "đang bận" chung chung) sang biết ĐANG BẬN VÌ HÀNH ĐỘNG NÀO (ví dụ thêm `_activeAction` — `'export'`/`'import'`/`null`) — để mỗi `CommonButton` chỉ `loading: true` đúng cái mình đang chạy, không phải cả 2 cùng lúc.
2. Truyền `loading: _activeAction == 'export'` cho nút Export, `loading: _activeAction == 'import'` cho nút Import — giữ nguyên `onTap: _busy ? null : _handle...` (CommonButton tự chặn tap khi `loading: true` rồi, nhưng giữ nguyên logic disable ở tầng gọi cũng không sai — cân nhắc khi implement có thể đơn giản hoá thành chỉ dựa vào `loading` của CommonButton, không cần disable kép).
3. Dòng 206-239 (`Row` spinner+text "Working…" riêng): sau khi 2 nút đã tự hiện spinner, cân nhắc BỎ hẳn phần hiện spinner+"Working…" trùng lặp này, CHỈ giữ lại phần hiện kết quả sau khi xong (success/error icon + message, `_status == success/error`) — quyết định cụ thể khi implement, ghi rõ lý do trong `## Quyết định`.

## Acceptance criteria
- [x] Nút Export hiện đúng spinner (qua `CommonButton.loading`) CHỈ khi đang export, không phải khi đang import (và ngược lại) — 2 nút không còn "cùng bận" 1 lượt như hiện tại.
- [x] Chặn double-tap vẫn đúng: bấm Export trong lúc đang export không kích hoạt thêm lần export thứ 2; tương tự cho Import.
- [x] Không phá luồng thành công/lỗi hiện có (`_Status.success`/`_Status.error` message vẫn hiện đúng sau khi xong).
- [x] Semantics: `liveRegion`/label vẫn phản ánh đúng trạng thái đang xử lý cho screen reader (không mất thông tin accessibility hiện có dù đổi cách hiện spinner).
- [x] Không đổi API public của `BackupRestorePanel` (constructor params) — đây thuần là refactor nội bộ State.
- [x] Test: cập nhật/bổ sung test trong file test tương ứng của `BackupRestorePanel` xác nhận đúng spinner-đúng-nút, không phá test export/import/error/cancel hiện có.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-67-backup-restore-panel-adopt-common-button-loading.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc TOÀN BỘ `lib/presentation/widgets/common/backup_restore_panel.dart` (cả `_handleExport`/`_handleImport`/build method) và file test hiện có của nó, cùng `lib/presentation/widgets/common/common_button.dart` (`loading` từ IDEA-53) trước khi sửa. Implement bằng TDD (viết test fail trước cho hành vi "đúng nút nào đang loading", rồi sửa code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng dọn dẹp trùng lặp, không phá bất kỳ luồng export/import/confirm-dialog/error hiện có, không over-engineer — chỉ đổi cách biểu diễn trạng thái bận, không viết lại toàn bộ widget).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu `BackupRestorePanel` được demo ở đó — kiểm tra trước bằng `grep -rn "BackupRestorePanel" example/`).
4. Nếu có demo thật trong `example/`: device smoke test trên máy đang online hiện có (kiểm tra `mobile_list_available_devices`/`mobile_get_foreground_app`/`ListAgents` FRESH trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`, và giải thích rõ quyết định có bỏ hẳn Row spinner riêng hay không), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `backup_restore_panel.dart` dòng 83 (`_busy` getter), dòng 173-184 (2 `CommonButton` không có `loading:`), dòng 206-239 (Row spinner+"Working…" riêng, hand-rolled, y hệt mô tả trong chính `doc/task/done/IDEA-53-common-button-loading-state.md`'s `## Hiện trạng`). Đây là bằng chứng mạnh nhất trong đợt audit này: task đã done (IDEA-53) TỰ TRÍCH DẪN file này làm lý do tồn tại, nhưng chưa quay lại dọn dẹp nó. Effort nhỏ-vừa (refactor nội bộ 1 StatefulWidget, không đổi API public), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Thêm `_Action` enum (`none`/`export`/`import`) song song `_Status`, gán `_activeAction` đúng lúc mỗi hành động bắt đầu/kết thúc, truyền `loading: _activeAction == _Action.export`/`import` xuống đúng `CommonButton` tương ứng — 2 nút giờ chỉ có ĐÚNG 1 nút hiện spinner tại 1 thời điểm, nút còn lại vẫn bị disable (qua `onTap: _busy ? null : ...` giữ nguyên) nhưng không hiện spinner của riêng nó.

**Quyết định về Row spinner+"Working…" cũ (dòng 206-239 gốc)**: BỎ HẲN phần hiển thị TRỰC QUAN (spinner + text "Working…") — vì mỗi nút giờ đã tự hiện spinner của chính nó, giữ nguyên phần này sẽ là 2 nguồn thông tin trùng lặp/rối mắt (đúng góc nhìn ban đầu nêu trong Hiện trạng). **NHƯNG giữ nguyên tín hiệu accessibility**: thay vì xoá hẳn `Semantics(liveRegion: true, ...)`, đổi thành 1 `Semantics` bọc `SizedBox` rỗng (không có gì hiển thị) nhưng vẫn còn `label: 'Working…'` — trình đọc màn hình vẫn được thông báo "đang xử lý" như cũ, chỉ bỏ phần NHÌN THẤY được (đúng yêu cầu "không mất thông tin accessibility hiện có dù đổi cách hiện spinner" trong acceptance criteria).

**Test:** 4 test mới trong `test/widget/common/backup_restore_panel_test.dart` nhóm "ENH-67" — đang export chỉ nút Export loading (Import vẫn disable nhưng không loading), đang import chỉ nút Import loading, bấm Export nhiều lần lúc đang export chỉ chạy đúng 1 lần (double-tap vẫn bị chặn dù giờ dựa vào `CommonButton.loading` thay vì chỉ dựa `onTap: null`), sau khi xong cả 2 nút hết loading. TOÀN BỘ 13 test cũ trong file vẫn pass nguyên vẹn, không cần sửa (kể cả test "hiện spinner, 2 nút bị vô hiệu hoá" cũ — vẫn đúng vì giờ có ĐÚNG 1 `CircularProgressIndicator` hiển thị, chỉ là nó nằm TRONG nút thay vì tách rời).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1164/1164 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 53/53 pass (demo `BackupRestorePanel` sẵn có trong `widget_showcase_screen.dart` không cần sửa gì, tự động hưởng lợi từ refactor).

**Cập nhật sau — device smoke test thật đã hoàn thành** (Samsung A50, `R58MA6WYRPE`, thiết bị thật, sau khi thiết bị dùng chung rảnh): mở demo `BackupRestorePanel` trong `Widget Kit`, bấm "Export save" → không throw, không crash; bấm "Restore save" → `ConfirmDialog` hiện đúng ("Restore save? This replaces all current progress..."), bấm OK → import thành công, không crash. `adb logcat` lọc `level=Error` trước/sau cả 2 thao tác: không có dòng nào. Do callback `onExport`/`onImport` trong demo hoàn thành gần như tức thời (không có delay giả lập như "Simulate async" của IDEA-53), khung hình loading/spinner riêng của từng nút không kịp bắt được qua screenshot — nhưng hành vi ĐÚNG (không throw, đúng luồng, đúng dialog) đã được xác nhận trên thiết bị thật, bổ sung cho 17/17 widget test đã verify chi tiết đúng-nút-nào-loading bằng `Completer` (test không phụ thuộc tốc độ demo thật).

**Tự chấm điểm: 9.5/10** — dọn dẹp đúng trùng lặp trạng thái (2 nguồn sự thật → 1), giữ đúng accessibility signal thay vì xoá trắng, test bao phủ đủ mọi case (đúng-nút-loading, double-tap-chặn, cleanup sau khi xong), không phá 13 test cũ, và nay đã có bằng chứng device thật (export/import/confirm dialog hoạt động đúng, không crash trên Samsung A50 thật) bổ sung cho bộ widget test.
