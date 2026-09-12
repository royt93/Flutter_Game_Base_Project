---
id: IDEA-36
title: "[Killer] Headless economy/balancing simulator — chạy nhanh N ngày economy trước khi ship"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: L
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới (tool riêng, không phải widget/service runtime) — dựa trên `lib/core/energy_service.dart`, `lib/core/offline_progression_service.dart`, `lib/core/daily_login_service.dart`, `lib/core/utils/weighted_random_pick.dart`.

## Hiện trạng
Kit này có 1 lõi hiếm gặp: toán học THUẦN, không phụ thuộc Flutter/thời gian thật — `EnergyService._regen`, `OfflineProgressionService._earningsAt`, `weightedRandomPick`, `PerformanceTierService` đều là hàm xác định (deterministic) của state/thời gian được TIÊM VÀO (không có `DateTime.now()`, không có `SchedulerBinding` trong phần toán học thật) — đúng tính chất cần cho 1 mô phỏng economy tua nhanh, và đúng tính chất mà 1 template Flutter thông thường KHÔNG BAO GIỜ có (game logic ở đó thường quấn chặt vào widget). 1 studio cân bằng tốc độ hồi năng lượng, cap offline, tỉ lệ loot table hôm nay chỉ có thể làm bằng cách playtest thủ công.

## Vì sao cần / Hậu quả
1 công cụ mô phỏng "30 ngày người chơi kịch bản" headless sẽ bắt được economy bị lỗi cân bằng TRƯỚC KHI ship 1 bản build, thay vì phát hiện sau khi người chơi thật đã trải nghiệm sai.

## Đề xuất
1 script/tool Dart thuần (`tool/economy_sim.dart`, KHÔNG phụ thuộc Flutter) chạy toán học của `EnergyService`/`OfflineProgressionService` với 1 đồng hồ giả lập và 1 pattern session kịch bản (N session/ngày, M năng lượng tiêu mỗi session), in ra đường cong tiền tệ/năng lượng qua các ngày mô phỏng; có thể (không bắt buộc) hiển thị read-only trong panel đã có sẵn của `debug_qa_overlay.dart` để kiểm tra nhanh trên máy.

## Acceptance criteria
- [ ] Tool chạy được độc lập (dart run tool/economy_sim.dart) không cần Flutter runtime, in ra bảng/đường cong số liệu qua N ngày mô phỏng.
- [ ] Kết quả mô phỏng khớp đúng với hành vi thật của EnergyService/OfflineProgressionService khi test chéo (chạy service thật qua cùng kịch bản thời gian, so sánh kết quả).
- [ ] Test: unit test cho chính logic mô phỏng (đảm bảo nó gọi đúng công thức pure của 2 service, không tự chế công thức riêng).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-36-headless-economy-simulator.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng độc đáo, tận dụng đúng điểm mạnh sẵn có (toán học thuần không dính Flutter) mà 1 template chung không có, nhưng effort L và giá trị phụ thuộc việc studio dùng kit có thực sự cần balance-tuning nghiêm túc hay không — không phải mọi game nhỏ cần tool này.
