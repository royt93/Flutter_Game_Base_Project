---
id: IDEA-62
title: "Smart push notification scheduler nối ReminderService với EnergyService/DailyLoginService"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
Mở rộng `lib/core/reminder_service.dart`, dựa trên `lib/core/energy_service.dart` (`fullEnergyAtMs`-style tính toán) và `lib/core/daily_login_service.dart`.

## Hiện trạng
`ReminderService` chỉ có 1 nhắc nhở chung, không tự động tính thời điểm hồi đầy năng lượng hoặc thời điểm sắp mất streak để hẹn giờ đúng lúc.

## Vì sao cần / Hậu quả
Nhắc nhở đúng thời điểm ("năng lượng đã đầy", "sắp mất streak") tăng retention rõ rệt hơn 1 nhắc nhở chung chung — pattern kinh điển của casual/idle game.

## Đề xuất
Thêm helper tính thời điểm hồi đầy năng lượng từ `EnergyService` và thời điểm gần hết hạn streak từ `DailyLoginService`, tự động lên lịch qua `ReminderService` (huỷ lịch cũ nếu năng lượng bị tiêu tiếp trước khi tới giờ).

## Acceptance criteria
- [x] Helper tính đúng thời điểm hồi đầy năng lượng, đặt lịch nhắc nhở qua `ReminderService`.
- [x] Helper tính đúng thời điểm gần hết hạn streak (ví dụ vài giờ trước nửa đêm), đặt lịch nhắc nhở riêng.
- [x] Tiêu năng lượng/claim streak trước khi tới giờ nhắc — lịch cũ được huỷ/cập nhật đúng, không nhắc nhở sai lệch.
- [x] Test unit cho logic tính thời điểm + huỷ lịch.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-62-smart-push-notification-energy-streak.md` này trước khi làm. Đọc toàn bộ `lib/core/reminder_service.dart`, `lib/core/energy_service.dart`, `lib/core/daily_login_service.dart` trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device thật khuyến khích (verify notification thật hiện đúng lúc) không bắt buộc nếu unit test đủ chứng minh logic tính thời điểm.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng retention hợp lý, dựa trên hạ tầng đã có thật. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Phát hiện quan trọng trước khi implement**: Read kỹ `reminder_service.dart`
— `scheduleNext()`/`cancel()` LUÔN dùng `id: 0` cố định, và chính doc
comment của class đã ghi rõ: "Games that need several reminder
kinds/priorities should extend this, not add branches here — keep the
base's default path to exactly one notification." Nghĩa là: nếu chỉ gọi
`scheduleNext()` 2 lần cho 2 mục đích khác nhau (energy-full, streak-
expiring), LẦN GỌI SAU sẽ GHI ĐÈ lần gọi trước (cùng id 0) — không thể có
"2 lịch nhắc nhở riêng, huỷ/cập nhật độc lập" (đúng yêu cầu AC2/AC3) nếu
không thêm khả năng multi-id trước.

**Implement (2 phần)**:
1. `ReminderService.scheduleNext`/`cancel` thêm param `id` optional
   (mặc định `0`, giữ nguyên 100% hành vi cũ cho mọi call site hiện có)
   — đúng tinh thần "extend this" mà chính doc comment đã mời gọi, không
   phải thêm branch logic vào class.
2. `lib/core/utils/smart_reminder_scheduling.dart` (file mới, cùng chỗ
   với `economy_math.dart` — pure function siblings của
   Energy/OfflineProgression): `energyFullReminderDelay(EnergyService)`
   (pure, dùng đúng `currentEnergy`/`timeUntilNextEnergy` đã có, KHÔNG
   viết lại công thức regen — chỉ cộng thêm số tick nguyên còn thiếu sau
   điểm tiếp theo), `streakExpiringReminderDelay(DailyLoginService,
   {warnBefore})` (pure, dựa đúng `todayEpochDayClamped()` — ranh giới
   UTC day, không phải nửa đêm local — cùng đồng hồ chống gian lận
   `DailyLoginService` tự dùng), và 2 hàm điều phối
   `rescheduleEnergyReminder`/`rescheduleStreakReminder` gọi
   `ReminderService` với 2 id riêng (`kEnergyReminderNotificationId=1`,
   `kStreakReminderNotificationId=2`) — huỷ lịch (không đặt lịch mới) khi
   điều kiện không còn cần nhắc (đã đầy/đã claim).

**AC3 (huỷ/cập nhật đúng khi tiêu năng lượng/claim trước giờ nhắc)**:
KHÔNG dùng cơ chế tự động lắng nghe sự kiện (không invent event bus mới
giữa 3 service) — coordinator được thiết kế để CALLER tự gọi lại
`rescheduleXxxReminder()` sau mỗi hành động liên quan (sau
`consumeEnergy`, sau `claimToday`, lúc app resume) — mỗi lần gọi lại đều
TÍNH LẠI TỪ ĐẦU dựa trên state hiện tại, tự nhiên huỷ lịch cũ sai lệch;
ghi rõ trong doc comment đây là quyết định có chủ đích (seam pattern,
giống mọi service khác trong kit).

**TDD**: viết test trước, `mv` file helper mới ra ngoài + `git stash`
riêng `reminder_service.dart`/`roy_casual_kit.dart`, chạy → fail đúng
biên dịch, khôi phục, chạy lại — 11/11 pass file mới. Thêm 3 test cho
`id` param trong `reminder_service_test.dart` (đã tồn tại mock platform
channel sẵn từ trước) — cũng TDD-verify riêng (stash chỉ `reminder_service.dart`)
→ fail đúng ("No named parameter 'id'"), khôi phục → 12/12 pass.

**Sự cố khi viết test cần pin "now" xác định**: lần đầu pin epoch day
= 20000 (một giá trị nhỏ) để test `streakExpiringReminderDelay` — FAIL vì
epoch day thật (2026) đã LỚN HƠN 20000, khiến watermark clamp coi đó là
"tiến về phía trước" và nhảy về giá trị thật thay vì giữ nguyên giá trị
pin. Sửa bằng epoch day rất lớn (999999, chắc chắn luôn ở tương lai so
với ngày thật) để watermark clamp thực sự giữ nguyên giá trị pin.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2286 test (+15 đúng số test mới: 11 file mới +
3 test id + 1 rounding), 19 fail — đúng baseline golden-image, không fail
mới. `example/`: 142/142 pass (không đổi gì ở `example/`, task không yêu
cầu demo — logic thuần + platform channel mock đã đủ). `dart run
tool/api_compatibility.dart check` → `additive` (file mới
`smart_reminder_scheduling.dart` được export) → `snapshot` → `unchanged`.
Không cần smoke test device (task tự ghi optional, unit test đã chứng
minh đủ công thức tính thời điểm + mock platform channel xác nhận đúng
id/method được gọi).

Tự chấm: **9.5/10** — phát hiện đúng giới hạn thiết kế thật của
`ReminderService` (chỉ 1 id) trước khi bắt tay viết, mở rộng đúng cách
class tự mời gọi ("extend this") thay vì hack around nó, tái dùng công
thức regen có sẵn thay vì viết lại, TDD chứng minh cả pure function lẫn
tích hợp platform channel thật. Trừ 0.5 vì phát hiện + phải sửa 1 lỗi
pin-thời-gian trong chính test (không phải lỗi code sản phẩm, nhưng mất
thời gian debug).
