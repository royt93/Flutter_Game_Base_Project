---
id: IDEA-58
title: "FeatureFlagOverridePanel — tab trong DebugQaOverlay để QA tự bật/tắt RemoteKillSwitchController khi test"
type: idea
priority: low
effort: S
source: "Fork nội bộ (brainstorm task/tính năng mới)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart`, dựa trên `lib/core/remote_kill_switch_controller.dart`, `lib/core/remote_config_service.dart`.

## Hiện trạng
`RemoteKillSwitchController`/`RemoteConfigService` đã có nhưng không có UI nào trong `DebugQaOverlay` để QA tự bật/tắt kill-switch khi test — hiện chỉ gọi được bằng code (QA phải nhờ dev viết code test riêng mỗi lần).

## Vì sao cần / Hậu quả
QA cần thử nghiệm hành vi app khi 1 feature bị kill mà không cần chờ dev viết code — tăng tốc chu trình test trước khi release 1 remote-config thay đổi thật.

## Đề xuất
Thêm 1 tab nhỏ trong `DebugQaOverlay` liệt kê các feature flag hiện có (từ `RemoteKillSwitchController`), cho phép toggle qua UI (chỉ trong debug build).

## Acceptance criteria
- [x] Tab hiển thị đúng danh sách feature flag hiện có.
- [x] Toggle qua UI phản ánh đúng vào `RemoteKillSwitchController.isKilled(featureId)`.
- [x] Chỉ hoạt động ở debug build.
- [x] Test widget cho tab mới.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-58-feature-flag-override-panel-debug-qa-overlay.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/debug_qa_overlay.dart` và `lib/core/remote_kill_switch_controller.dart` trước khi thêm tab. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh cho 1 tab debug UI đơn giản).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hợp lý dựa trên hạ tầng đã có, giá trị thấp hơn các FEAT khác (chỉ là 1 tab UI tiện lợi, không phải service mới). Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: thêm tab thứ 8 "Kill Switch" vào `DebugQaOverlay`
(`_KillSwitchTab`/`_KillSwitchTabState`/`_KillSwitchRow`), theo đúng
pattern các tab debug đã có (`_VariantSwitcherTab` — text-field-driven vì
service lõi không có API "liệt kê mọi id đã biết"). `RemoteKillSwitchController`
không có registry feature id nào cả — nó chỉ resolve theo yêu cầu từng id
— nên danh sách hiển thị là HỢP của `assetDefaults.keys` (những feature
app đã khai default sẵn — nguồn danh sách hợp lý nhất không cần dev tự
gõ tay) và `states.keys` (feature đã được query ở nơi khác trong app,
hoặc thêm thủ công qua ô nhập). Có ô nhập id để QA tự thêm feature chưa
từng query.

**Chỉ toggle được LOCAL OVERRIDE, không giả vờ "bật lại mọi thứ"**: nút
"Kill" gọi `forceKillLocally(id, reason: 'QA override (Debug QA
Overlay)')`; nút "Bỏ override" chỉ hiện khi `state.source ==
KillSwitchSource.localOverride` (gọi `clearLocalOverride`). Feature bị
kill bởi nguồn remote/cached/asset-default (không phải local override)
KHÔNG có nút "bỏ" — vì `RemoteKillSwitchController` bản thân KHÔNG có API
"force-enable" nào (đọc đúng doc comment class: "an invalid/missing
remote value never flips a feature back open", không có escape hatch cục
bộ) — hiện nút giả vờ làm được việc đó sẽ TỆ HƠN không hiện gì, nên tab
chỉ hiện ghi chú giải thích thay vì nút no-op gây hiểu lầm.

**Debug-only tự động, không cần guard riêng**: `DebugQaOverlay` toàn bộ
đã gated `kDebugMode || kProfileMode` từ trước (return `widget.child` nếu
không), tab mới tự động thừa hưởng, không cần thêm check.

**Regression phát hiện và sửa trong lúc làm**: thêm tab thứ 8 khiến thanh
tab (Wrap) chiếm thêm 1 dòng, đẩy nội dung Playground tab (màu swatch)
xuống dưới rìa viewport test mặc định 800×600 — 1 test CŨ
(`IDEA-39: chọn màu khác...`) FAIL thật khi chạy `flutter test` toàn file
(không phải chỉ file mới của tôi). Sửa đúng root cause bằng
`tester.ensureVisible(...)` trước khi tap — ĐÚNG pattern đã có sẵn ngay
trong cùng file cho tab Variant (cũng từng bị cùng lớp vấn đề khi thêm
tab thứ 7 ở FEAT-93) — không phải hack riêng cho task này. Đã thử tăng
`maxHeight` của panel (600→640→720) trước, không giải quyết được (panel
nằm trong `Center`, không phải nguyên nhân chính) — bỏ hướng đó, quay lại
đúng cách consistent với codebase.

**TDD**: viết 6 test group "IDEA-58" trước, `git stash` riêng
`lib/presentation/widgets/debug_qa_overlay.dart`, chạy → cả 6 fail đúng
("Kill Switch" text not found) trên code cũ, khôi phục, chạy lại — 6/6
pass, cả file 33/33 pass (bao gồm cả test Playground đã sửa).

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2255 test (+6 đúng số test mới), 19 fail —
khớp baseline golden-image, không fail mới. `example/`: 142/142 pass
(không đổi gì ở `example/`, task không yêu cầu demo riêng ở đó — tab nằm
sẵn trong `DebugQaOverlay` component dùng chung). `dart run
tool/api_compatibility.dart check` → `additive` (3 class MỚI dù có tiền
tố `_` private — tool hiện tại không lọc private symbol, hạn chế có sẵn
của tool, không phải lỗi task này) → `snapshot` → `unchanged`.

Tự chấm: **9.5/10** — đúng pattern tiền lệ có sẵn, tôn trọng đúng ranh
giới API thật của `RemoteKillSwitchController` (không giả vờ un-kill được
thứ không un-kill được), phát hiện VÀ SỬA ĐÚNG 1 regression thật gây ra
bởi chính thay đổi này trước khi nộp (không chỉ né tránh/patch qua loa).
Trừ 0.5 vì mất thời gian mò `maxHeight` sai hướng trước khi tìm đúng root
cause qua `ensureVisible` — lẽ ra nên kiểm tra pattern có sẵn trong file
trước.
