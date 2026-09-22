---
id: BUG-69
title: "regenEnergy() crash IntegerDivisionByZeroException nếu intervalMs <= 0"
type: bug
priority: P2
effort: XS
source: "agy (độc lập), verify lại qua Read lib/core/utils/economy_math.dart"
---

## Vị trí
`lib/core/utils/economy_math.dart` — `regenEnergy(...)`, biểu thức `(nowMs - lastMs) ~/ intervalMs`.

## Hiện trạng
Không có validate `intervalMs > 0` trước khi chia nguyên (`~/`). Nếu `intervalMs` bằng 0 (do cấu hình sai từ CMS/remote config/game-balance JSON), phép chia nguyên với 0 ném `IntegerDivisionByZeroException` ngay lập tức.

## Vì sao cần / Hậu quả
`economy_math.dart` là hàm thuần được `EnergyService` VÀ `tool/economy_sim.dart` (công cụ balance headless) cùng gọi — 1 cấu hình `intervalMs: 0` sai (dễ xảy ra nếu balance designer nhập nhầm hoặc dùng giá trị mặc định hụt từ JSON) crash cả app thật lẫn công cụ simulator balance.

## Đề xuất
Thêm validate đầu hàm: `if (intervalMs <= 0) throw ArgumentError.value(intervalMs, 'intervalMs', 'must be > 0');`.

## Acceptance criteria
- [ ] `regenEnergy(..., intervalMs: 0)` throw `ArgumentError` rõ ràng thay vì `IntegerDivisionByZeroException` mơ hồ.
- [ ] `regenEnergy(..., intervalMs: -1)` cũng bị chặn tương tự.
- [ ] `intervalMs > 0` hành vi không đổi so với hiện tại.
- [ ] Test hiện có của `economy_math_test.dart` và `test/tool/economy_sim_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-69-economy-math-regen-divide-by-zero.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/economy_math.dart` và test hiện có (bao gồm `test/tool/economy_sim_test.dart` — cross-check với `tool/economy_sim.dart`) trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix 1 dòng validate, unit test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — logic mô tả (chia nguyên không validate mẫu số) là loại lỗi dễ kiểm chứng và phổ biến; chưa tự Read lại đúng dòng do khối lượng batch verify, nhưng rủi ro thấp (fix rất nhỏ, không thể gây regression nếu chỉ thêm validate đầu hàm). Không trùng task nào trong `doc/task/done/`.
