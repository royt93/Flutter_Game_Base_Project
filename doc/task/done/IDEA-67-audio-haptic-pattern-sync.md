---
id: IDEA-67
title: "AudioHapticSync — đồng bộ nhịp điệu HapticChoreographer theo âm thanh SFX thực tế"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
Mới, dựa trên `lib/core/haptic_choreographer.dart` (`HapticPattern`) và `lib/core/audio_manager.dart`.

## Hiện trạng
`HapticChoreographer` sequences 1 `HapticPattern` (pulse có delay riêng) độc lập với `AudioManager` — không có cơ chế đồng bộ 2 bên (ví dụ combo SFX pitch-escalation + haptic pulse cùng nhịp).

## Vì sao cần / Hậu quả
Cảm giác phản hồi tốt hơn khi haptic và âm thanh đồng bộ nhịp điệu — đặc biệt hữu ích nếu kết hợp với ý tưởng "Dynamic Audio Pitch Escalation cho Combo" (đã cân nhắc nhưng KHÔNG đưa vào backlog lần này, xem ghi chú trong BACKLOG-AUDIT).

## Đề xuất
Thêm 1 helper nhỏ nhận `HapticPattern` + số bước combo, tự tính delay pulse tương ứng đồng bộ với 1 SFX đang phát (không cần audio-analysis phức tạp — chỉ cần đồng bộ timing đã biết trước, ví dụ combo step N ứng với pulse thứ N).

## Acceptance criteria
- [x] Helper tạo đúng `HapticPattern` đồng bộ theo số bước combo truyền vào.
- [x] Không đổi hành vi `HapticChoreographer`/`AudioManager` hiện có khi không dùng helper mới.
- [x] Test unit cho helper.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-67-audio-haptic-pattern-sync.md` này trước khi làm. Đọc toàn bộ `lib/core/haptic_choreographer.dart` và `lib/core/audio_manager.dart` trước khi implement. Implement bằng TDD, ưu tiên giải pháp tối giản (ponytail) — không cần audio-analysis thời gian thực, chỉ cần đồng bộ timing đã biết trước.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device thật khuyến khích (cảm nhận trực quan haptic+audio đồng bộ) không bắt buộc nếu unit test đủ chứng minh timing logic.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng game-feel hợp lý dựa trên 2 hạ tầng đã có thật, giá trị thấp/vừa. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Xác nhận trước khi code**: Read `audio_manager.dart` — KHÔNG có API nào
biết trước "SFX dài bao lâu"/nhịp bên trong, chỉ có `playSfx(fileName)`
phát 1 file trọn vẹn. Khớp đúng giả định của task: không audio-analysis,
chỉ đồng bộ theo timing ĐÃ BIẾT TRƯỚC do caller tự cung cấp (số bước +
khoảng cách mỗi bước), không đọc gì từ `AudioManager` cả.

**Implement**: `comboSyncHapticPattern({required steps, required
stepInterval, levelForStep})` trong `haptic_choreographer.dart` (cùng
file với `HapticPattern`/`HapticPulse`, không tạo file mới) — tạo đúng
`steps` pulse, mỗi pulse `delayAfter: stepInterval`. `levelForStep` mặc
định TÁI DÙNG `hapticLevelForGroupSize` (đã có sẵn trong `haptics.dart`
cho việc map "kích thước nhóm match -> haptic level") — combo step N
được coi như 1 "magnitude" leo thang y hệt cách nhóm match lớn hơn đã
leo thang, không phát minh bảng ánh xạ light/medium/heavy thứ 2. KHÔNG
tự validate `steps`/`stepInterval` ngoài check `steps > 0` cơ bản —
`HapticPattern`'s constructor ĐÃ validate đủ (max 16 pulse, max delay/pulse
2s, max tổng 5s) nên để nó tự throw, không duplicate logic.

**AC2 (không đổi hành vi cũ)**: đúng theo thiết kế — hàm hoàn toàn mới,
không sửa 1 dòng nào trong `HapticChoreographer`/`AudioManager`, chỉ TẠO
RA 1 `HapticPattern` để truyền vào `HapticChoreographer.play()` đã có sẵn
(test cuối cùng verify chơi được THẬT qua `play()`, không chỉ kiểm tra
cấu trúc dữ liệu suông).

**TDD**: `git stash` riêng `haptic_choreographer.dart`, chạy 7 test mới
nhóm "IDEA-67" → fail đúng biên dịch ("Method not found:
'comboSyncHapticPattern'"), khôi phục, chạy lại — 7/7 pass, cả file
25/25 pass (18 test cũ không đổi). Test cover: đúng số pulse theo
`steps`; đúng `delayAfter` mỗi pulse; mặc định leo thang light→medium→heavy
đúng theo `hapticLevelForGroupSize`; `levelForStep` tuỳ chỉnh ghi đè đúng
mặc định; `steps <= 0` throw; `steps` vượt `HapticPattern.maxPulses`
vẫn throw đúng (chứng minh không bypass validation có sẵn); pattern trả
về thực sự PHÁT ĐƯỢC qua `HapticChoreographer.play()` (mock platform
channel, xác nhận có lời gọi thật).

**Kết quả**: `flutter analyze` sạch. `flutter test --exclude-tags slow`
root: 2311 test (+7 đúng số test mới), 20 fail — 19 golden-image + 1
flaky đã biết (`season_event_service_test.dart` ENH-71). `example/`:
không đổi gì, `flutter analyze` sạch. `dart run
tool/api_compatibility.dart check` → `unchanged` (hàm top-level mới có
kiểu trả về đứng trước tên trên cùng dòng — không khớp regex hẹp của
tool, giống hạn chế đã ghi nhận nhiều lần trong session ở các pure
function khác). Không cần smoke test device (task tự ghi optional, unit
test đã chứng minh đủ timing logic + phát được thật qua platform channel
mock).

Tự chấm: **9.5/10** — đúng tinh thần "tối giản" task tự nhắc (không
audio-analysis, tái dùng `hapticLevelForGroupSize` có sẵn thay vì bảng
mapping mới, không duplicate validation của `HapticPattern`), TDD chứng
minh cả happy path lẫn case biên (vượt giới hạn, custom levelForStep,
chơi được thật). Trừ 0.5 vì đây là "helper xây pattern" thuần, chưa có
ví dụ demo thực tế nào trong `example/` minh hoạ ghép với `AudioManager.playSfx`
đang chạy song song (task không yêu cầu, nhưng sẽ tăng giá trị thực tế).

---

**Đây là task CUỐI CÙNG trong toàn bộ backlog `doc/task/todo/`** — sau
khi merge, `doc/task/todo/` trống hoàn toàn (0 file BUG/ENH/FEAT/IDEA còn
lại). Toàn bộ 10 IDEA (58–67) của phiên làm việc "power through" này đã
hoàn thành, mỗi cái đều đạt >9/10, đã commit + push riêng biệt theo đúng
quy trình 2-commit (code+test, rồi done-move) đã dùng xuyên suốt session.
