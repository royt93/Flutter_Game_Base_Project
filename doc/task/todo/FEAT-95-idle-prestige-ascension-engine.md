---
id: FEAT-95
title: "PrestigeService — cơ chế trùng sinh/thăng hoa (soft-reset đổi lấy meta-currency vĩnh viễn) kinh điển của idle game"
type: feature
priority: P1
effort: M
source: "agy (độc lập)"
---

## Vị trí
Mới `lib/core/prestige_service.dart` — dựa trên `lib/core/economy_wallet.dart`, `lib/core/offline_progression_service.dart`, `lib/core/utils/economy_math.dart`.

## Hiện trạng
Kit đã có `OfflineProgressionService` và `EconomyWallet` nhưng thiếu hoàn toàn engine quản lý vòng đời "Prestige" — cơ chế cốt lõi của mọi tựa game Idle/Incremental (Cookie Clicker, Adventure Capitalist): người chơi tích luỹ tài nguyên đến ngưỡng, kích hoạt soft-reset các tài nguyên cấp thấp, quy đổi sang meta-currency vĩnh viễn với hệ số nhân tăng dần.

## Vì sao cần / Hậu quả
Đây là gap thể loại rõ ràng nhất cho 1 "casual/idle-game SDK" — thiếu cơ chế này khiến kit chưa thật sự đủ cho genre idle/incremental dù đã có phần lớn hạ tầng kinh tế cần thiết.

## Đề xuất
Thêm `PrestigeService`: `canPrestige()` (đủ ngưỡng tài nguyên), `prestige()` (soft-reset tài nguyên cấp thấp qua `EconomyWallet`, cộng meta-currency theo công thức `multiplier = 1 + (relics * bonusPerRelic)` — hàm thuần trong `economy_math.dart` để `tool/economy_sim.dart` cross-check được), `currentMultiplier` (hệ số nhân đang áp dụng cho earn rate).

## Acceptance criteria
- [ ] `PrestigeService.canPrestige()` đúng theo ngưỡng cấu hình.
- [ ] `prestige()` soft-reset đúng tài nguyên cấp thấp, cộng đúng meta-currency, không mất/nhân đôi dữ liệu.
- [ ] `currentMultiplier` áp dụng đúng vào rate tính toán của `OfflineProgressionService`/`EnergyService` (nếu tích hợp) sau khi prestige.
- [ ] Công thức tính multiplier là hàm thuần trong `lib/core/utils/economy_math.dart`, có cross-check trong `tool/economy_sim.dart`/`test/tool/economy_sim_test.dart` (đúng convention hiện có).
- [ ] Test unit đầy đủ, demo trong `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-95-idle-prestige-ascension-engine.md` này trước khi làm. Đọc toàn bộ `lib/core/economy_wallet.dart`, `lib/core/offline_progression_service.dart`, `lib/core/utils/economy_math.dart`, `tool/economy_sim.dart` (convention hàm thuần dùng chung giữa service thật và simulator) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria, kể cả cross-check `tool/economy_sim.dart`.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device thật khuyến khích (demo prestige trong example, verify UI/số liệu đúng) không bắt buộc nếu unit/widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — gap thể loại rõ ràng, hợp lý cho định hướng "casual/idle-game SDK" của kit; dựa trên hạ tầng kinh tế đã có thật (`EconomyWallet`, `economy_math.dart`). Không trùng task nào trong `doc/task/done/`.
