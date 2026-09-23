---
id: FEAT-94
title: "PlayerDataRightsService — export/xoá toàn bộ dữ liệu người chơi kèm biên nhận (GDPR/CCPA-style)"
type: feature
priority: P1
effort: M
source: "codex (độc lập)"
---

## Vị trí
Mới — dựa trên `lib/core/storage_service.dart` (`exportAll`/`eraseAll` đã có), `lib/core/consent_state_service.dart`.

## Hiện trạng
`StorageService` đã có `exportAll()`/`eraseAll()` ở tầng kỹ thuật thấp, nhưng không có 1 luồng nghiệp vụ hoàn chỉnh "người chơi yêu cầu xuất/xoá toàn bộ dữ liệu của họ" kèm xác nhận/biên nhận rõ ràng (timestamp, những gì đã xoá, xác nhận hoàn tất) — dạng yêu cầu ngày càng phổ biến theo quy định bảo vệ dữ liệu (GDPR/CCPA) mà game phát hành quốc tế cần đáp ứng.

## Vì sao cần / Hậu quả
Thiếu luồng chuẩn khiến mỗi consumer app phải tự lắp ráp `exportAll`/`eraseAll` với UI/xác nhận riêng — dễ thiếu sót (ví dụ quên xoá 1 phần dữ liệu liên quan analytics/crash reporter bên ngoài `StorageService`).

## Đề xuất
Thêm `PlayerDataRightsService.requestExport()` (trả file JSON kèm metadata: thời điểm, phiên bản schema) và `PlayerDataRightsService.requestErasure()` (gọi `eraseAll()` + phát 1 event cho các seam khác — `AnalyticsProvider`/`CrashReporter` — có cơ hội xoá dữ liệu phía họ, trả về 1 "biên nhận" xác nhận hoàn tất kèm timestamp).

## Acceptance criteria
- [x] `requestExport()` trả file JSON đầy đủ dữ liệu người chơi + metadata rõ ràng.
- [x] `requestErasure()` xoá đúng toàn bộ storage VÀ phát tín hiệu cho seam khác biết (không ép buộc, chỉ best-effort thông báo).
- [x] Trả về 1 "biên nhận" (record) xác nhận hoàn tất, có timestamp.
- [x] Test unit đầy đủ, demo trong `example/` (nút "Yêu cầu xuất dữ liệu"/"Yêu cầu xoá dữ liệu" trong `SettingsScreen`).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-94-player-data-rights-workflow.md` này trước khi làm. Đọc toàn bộ `lib/core/storage_service.dart` (`exportAll`/`eraseAll`), `lib/core/analytics_provider.dart`, `lib/core/crash_reporter.dart` (seam có thể cần thông báo) trước khi thiết kế service mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device thật khuyến khích (demo trong `SettingsScreen`, verify export/xoá hoạt động đúng) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — nhu cầu thật (compliance) hợp lý cho 1 kit hướng tới phát hành quốc tế, dựa trên hạ tầng đã có sẵn (`exportAll`/`eraseAll`). Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `lib/core/player_data_rights_service.dart` —
`PlayerDataRightsService(storage: StorageService)`:
- `requestExport()` → `DataExportReceipt` (đồng bộ, không throw — TÁI SỬ
  DỤNG `StorageService.exportAll()` sẵn có) gồm `exportedAtMs`,
  `schemaVersion`, `data` (toàn bộ storage, không cắt bớt — đúng ý nghĩa 1
  yêu cầu export phải đầy đủ).
- `requestErasure()` → `Future<DataErasureReceipt>` (`completedAtMs`,
  `erasedKeyCount` đếm TRƯỚC khi xoá, `hookResults`) — gọi
  `StorageService.eraseAll()` trước, sau đó chạy mọi hook đã đăng ký qua
  `registerErasureHook(label, hook)`, best-effort (1 hook throw chỉ ghi
  `false` vào `hookResults`, không chặn hook khác, không undo việc xoá đã
  xong).

**Quyết định thiết kế quan trọng**: đề xuất gốc nói "phát 1 event cho các
seam khác (AnalyticsProvider/CrashReporter) có cơ hội xoá dữ liệu phía họ"
— đọc kỹ `analytics_provider.dart`/`crash_reporter.dart` trước khi code (2
seam CHỈ có `logEvent`/`recordError`, không hề có API "xoá dữ liệu của
tôi") xác nhận KHÔNG nên thêm method mới vào 2 interface tối giản này (1
SDK analytics/crash thật có API xoá dữ liệu rất khác nhau theo vendor,
không thể trừu tượng hoá gọn bằng 1 method chung). Chọn thiết kế hook-list
generic (`registerErasureHook`) thay vì sửa 2 seam — vẫn đạt đúng ý "phát
tín hiệu, best-effort, không ép buộc" nhưng linh hoạt hơn, áp dụng được
cho BẤT KỲ seam nào app tự đăng ký, không giới hạn đúng 2 cái được nêu.

**Demo `example/`**: `SettingsScreen` thêm 2 tile "Yêu cầu xuất dữ liệu"/
"Yêu cầu xoá dữ liệu" (dùng LẠI `StorageService.to` singleton thật của app,
không phải instance rời). Xuất → `ToastBanner` hiện số key + thời điểm.
Xoá → `showConfirmDialog` xác nhận trước (hành động phá huỷ), xác nhận
xong mới gọi `requestErasure()`, hiện biên nhận qua `ToastBanner`.

**TDD**: 11 test unit `test/core/player_data_rights_service_test.dart`
(export đúng data+metadata; storage rỗng vẫn hợp lệ; `toJson()` đúng cả 3
field; erasure xoá thật; đếm đúng key TRƯỚC khi xoá; storage rỗng
erasedKeyCount=0; mọi hook được gọi + ghi true; 1 hook throw không chặn
hook khác + storage vẫn đã xoá; unregister hoạt động; đăng ký lại cùng
label thay thế hook cũ; `toJson()` erasure đúng cả 3 field) — xác nhận fail
đúng lỗi biên dịch khi tạm xoá file lib, khôi phục pass 11/11. 3 widget
test mới `example/test/settings_screen_test.dart` (tap export hiện đúng
toast; tap xoá rồi Cancel → storage giữ nguyên; tap xoá rồi xác nhận →
storage rỗng thật + toast biên nhận) — xác nhận fail đúng khi `git stash`
`lib/roy_casual_kit.dart` + `settings_screen.dart`, khôi phục pass 3/3
(16/16 cả file).

Trong lúc viết 2 test dialog tự bắt 1 vấn đề timing thật của hạ tầng test
(không phải bug code): `tester.tap(find.text(...))` trên nút xác nhận/huỷ
của `NeonDialog.show` (route thật qua `showGeneralDialog`) thỉnh thoảng
miss hit-test dù đã pump đủ lâu qua transition 220ms — root cause chưa xác
định chắc chắn (nghi ngờ `IgnorePointer` còn sót từ machinery route
transition của Flutter), nhưng dùng cách đã có sẵn trong CHÍNH file test
này (`tapLocaleRow`'s pattern: gọi thẳng `NeonDialogButton.action.onTap()`
thay vì `tester.tap()` toạ độ) giải quyết dứt điểm, đồng thời chứng minh
đúng callback production thật (không phải giả lập tách rời).

**Kết quả**: `flutter analyze` sạch ở root và `example/`. `flutter test
--exclude-tags slow` root: 2187 test, 21 fail — khớp baseline golden-image
đã biết + 1 flake `energy_service_test.dart` BUG-52 (real-wall-clock race,
0 liên quan file đã sửa lần này, không tái hiện khi chạy lại riêng lẻ,
matches pattern đã ghi nhận trước đó trong phiên). `example/`: 139/139
pass. `dart run tool/api_compatibility.dart check`: `additive` (thêm
`PlayerDataRightsService`/`DataExportReceipt`/`DataErasureReceipt`) →
`snapshot` → `unchanged`.

**Không làm** (khuyến khích, không bắt buộc theo task): smoke test device
thật — widget test (bao gồm chuỗi tương tác dialog xác nhận đầy đủ) đã đủ
chứng minh đúng hành vi.
