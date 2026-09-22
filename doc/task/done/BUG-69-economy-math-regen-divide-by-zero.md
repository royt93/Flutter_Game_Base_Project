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
- [x] `regenEnergy(..., intervalMs: 0)` throw `ArgumentError` rõ ràng thay vì `IntegerDivisionByZeroException` mơ hồ.
- [x] `regenEnergy(..., intervalMs: -1)` cũng bị chặn tương tự.
- [x] `intervalMs > 0` hành vi không đổi so với hiện tại.
- [x] Test hiện có của `economy_math_test.dart` và `test/tool/economy_sim_test.dart` vẫn pass.

## Quyết định
Fix đúng 100% đề xuất trong task, đặt validate NGAY ĐẦU hàm — QUAN TRỌNG: trước cả nhánh early-return "đã đầy tim" (`count >= maxEnergy`), không phải chỉ trước dòng chia — vì nếu đặt sau early-return, `intervalMs<=0` chỉ crash khi `count` CHƯA đầy, khiến bug ẩn/lộ tuỳ trạng thái năng lượng hiện tại thay vì báo lỗi nhất quán mọi lúc. Cùng convention với `offlineEarnings` (hàm chị em ngay bên dưới trong cùng file, đã validate kiểu này từ trước).

Phát hiện thêm khi verify: `intervalMs` ÂM (khác 0) không crash `IntegerDivisionByZeroException` — Dart cho phép chia nguyên với số âm (`~/` không lỗi), chỉ cho ra kết quả SAI ÂM THẦM (`ticks` âm, bị điều kiện `ticks <= 0` bắt và early-return im lặng, không cộng energy dù thực ra intervalMs cấu hình sai). Đây là bug KHÁC (sai kết quả im lặng, không phải crash) nhưng vẫn nằm trong đúng phạm vi "intervalMs không hợp lệ" mà task đã liệt kê ở criterion 2 — fix chung 1 validate `<= 0` xử lý đúng cả 2 trường hợp (0 crash, âm sai âm thầm) cùng lúc.

`EnergyService` (caller thật duy nhất trong app) đã validate `refillInterval > 0` từ constructor riêng (BUG-19) nên KHÔNG BAO GIỜ gọi `regenEnergy` với `intervalMs<=0` qua đường app thật — rủi ro thực tế chủ yếu ở `tool/economy_sim.dart` (nhận `intervalMs` trực tiếp từ CLI args/JSON balance config, không qua constructor guard nào).

**TDD verify**: `git stash` riêng `lib/core/utils/economy_math.dart`, chạy 3 test mới — FAIL đúng trên code cũ (`intervalMs: 0` crash `IntegerDivisionByZeroException` thay vì `ArgumentError`; `intervalMs: -100` và `intervalMs: 0` khi `count` đã đầy đều KHÔNG throw gì cả, chỉ trả kết quả sai âm thầm). `git stash pop`, chạy lại — 16/16 pass toàn file `economy_math_test.dart`, 8/8 pass `test/tool/economy_sim_test.dart` (cross-check simulator/service thật không đổi), 28/28 pass `energy_service_test.dart` (không ảnh hưởng vì constructor guard riêng đã chặn từ trước).

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2098 pass / -19 fail (baseline golden có sẵn, không liên quan), `dart run tool/api_compatibility.dart check` unchanged.

Tự chấm: **9.5/10** — root cause đúng, đặt validate ở đúng vị trí (trước early-return, không chỉ trước dòng chia), phát hiện thêm case "âm thầm sai" cho intervalMs âm mà mô tả gốc chỉ nói về crash, TDD 3 chiều (0/âm/đã đầy) chứng minh đầy đủ, không phá bất kỳ test nào của 3 file liên quan.

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
