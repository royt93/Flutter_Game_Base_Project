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
- [x] Tool chạy được độc lập (dart run tool/economy_sim.dart) không cần Flutter runtime, in ra bảng/đường cong số liệu qua N ngày mô phỏng.
- [x] Kết quả mô phỏng khớp đúng với hành vi thật của EnergyService/OfflineProgressionService khi test chéo (chạy service thật qua cùng kịch bản thời gian, so sánh kết quả).
- [x] Test: unit test cho chính logic mô phỏng (đảm bảo nó gọi đúng công thức pure của 2 service, không tự chế công thức riêng).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. **N/A**: tool Dart thuần, không có UI/widget nào (xem `## Quyết định`).
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. **N/A**: không có widget.

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

## Quyết định

**Phát hiện quan trọng trước khi code:** `EnergyService._regen()`/`OfflineProgressionService._earningsAt()` tuy đúng là "hàm xác định, không có `DateTime.now()` trực tiếp" như Hiện trạng mô tả, nhưng KHÔNG phải hàm pure độc lập theo nghĩa "nhận state/thời gian tiêm vào, trả ra state mới" — cả 2 đều là method riêng (`private`), đọc/ghi thẳng `StorageService.to` (singleton toàn cục) và tự gọi `nowMsClamped()` bên trong. Một tool Dart thuần "không phụ thuộc Flutter" không thể gọi thẳng 2 method này (chúng gắn chặt với `GetxService`/`StorageService`/`package:flutter`). Để thoả đúng AC "gọi đúng công thức pure của 2 service, không tự chế công thức riêng" ở mức MẠNH NHẤT (cùng 1 function, không phải 2 công thức "tương đương"), đã **refactor trước**: trích xuất đúng phần toán học thuần ra `lib/core/utils/economy_math.dart` (`regenEnergy(...)`, `offlineEarnings(...)` — zero dependency `flutter`/`get`/`StorageService`), rồi sửa `EnergyService._regen()`/`OfflineProgressionService._earningsAt()` để GỌI LẠI đúng 2 hàm này thay vì giữ nguyên logic trùng lặp tại chỗ. Từ đó `tool/economy_sim.dart` và 2 service thật cùng import chung 1 nguồn công thức duy nhất — không còn khái niệm "công thức tương đương", chỉ có "cùng 1 công thức".

**`tool/economy_sim.dart`:** script Dart thuần (`dart:io` + `package:roy_casual_kit/core/utils/economy_math.dart`, KHÔNG import `flutter`/`get`), chạy được qua `dart run tool/economy_sim.dart` không cần Flutter SDK ở bước build. Hàm `simulateEconomy(EconomyScenario)` (tách riêng khỏi `main()`, testable trực tiếp) mô phỏng N ngày × M session/ngày: mỗi session claim offline earnings trước (`offlineEarnings`), rồi hồi + tiêu năng lượng (`regenEnergy` + trừ trực tiếp, mô phỏng đúng quy tắc `consumeEnergy` — không đủ thì giữ nguyên không trừ, chỉ reset baseline hồi giờ khi tiêu từ lúc ĐẦY, giống hệt `EnergyService.consumeEnergy`'s `nowFullBeforeSpend` logic). `parseArgs` đọc `--key=value`, bỏ qua key lạ/giá trị hỏng (giữ default) — tool cân bằng nội bộ, không cần validate nghiêm ngặt như API công khai.

**Không tích hợp `debug_qa_overlay.dart`:** Đề xuất tự ghi rõ "có thể (KHÔNG BẮT BUỘC)" — bỏ qua để giữ đúng phạm vi effort, tránh mở rộng UI không được yêu cầu (ponytail). Cũng không đụng `weighted_random_pick.dart` dù được nhắc trong mục "Vị trí" — AC cụ thể chỉ yêu cầu cross-check với EnergyService/OfflineProgressionService, không nhắc loot table; thêm vào sẽ là scope creep không có tiêu chí nào ràng buộc.

**Test — 3 lớp:**
1. `test/core/utils/economy_math_test.dart` (12 test) — unit thuần cho `regenEnergy`/`offlineEarnings`: đầy tim không đổi, chưa đủ tick không đổi, đúng 1 tick, nhiều tick giữ lại phần dư, cap đúng ở max, vặn đồng hồ lùi không tick âm; earnings đúng công thức, cap đúng, validate lỗi input, vặn đồng hồ lùi earnings=0 không âm.
2. `test/tool/economy_sim_test.dart` (8 test) — `simulateEconomy` (session đầu currency=0, không đủ năng lượng không trừ/không âm, đúng số ngày, currency đơn điệu tăng), `parseArgs` (default, override hợp lệ, bỏ qua key lạ/giá trị hỏng), **cross-check** (chạy `EnergyService`/`OfflineProgressionService` THẬT qua đúng 1 kịch bản thời gian y hệt `simulateEconomy`, so sánh kết quả cuối — currency VÀ energy khớp 100%), và 1 test subprocess (`Process.run('dart', ['run', 'tool/economy_sim.dart', ...])`) xác nhận chạy độc lập thật sự qua `dart run`, không phải giả lập trong process test.

**Bug tự bắt được trong lúc viết cross-check test (flaky khi chạy full suite, không phải khi chạy riêng file):** ban đầu neo mốc thời gian giả lập bằng `baseMs = _realMs` (đúng bằng đồng hồ thật tại thời điểm capture) rồi set `StorageKeys.maxMsSeen = baseMs + nowMs` với `nowMs` bắt đầu từ 0. Vấn đề: `nowMsClamped()` = `max(đồng hồ thật LÚC ĐỌC, watermark đã lưu)` — ở session ĐẦU TIÊN (`nowMs=0`), giữa lúc capture `baseMs` và lúc `claim()` thực sự gọi `nowMsClamped()` đã trôi qua vài mili-giây thực thi code thật, khiến đồng hồ thật lúc đó > `baseMs+0`, nên `nowMsClamped()` trả về đồng hồ thật (lệch vài ms) thay vì đúng `baseMs`. Giá trị lệch nhỏ này bị `OfflineProgressionService` LƯU LẠI vĩnh viễn vào `offlineLastClaimedMs`, tạo ra 1 độ lệch cố định (không tự sửa) khiến earnings tích luỹ cuối cùng SAI lệch nhẹ so với simulator (`9000.0` kỳ vọng vs `8999.9995` thực tế) — chỉ lộ ra khi chạy TOÀN BỘ suite (máy chậm hơn, độ trễ giữa 2 dòng code lớn hơn), không lộ khi chạy riêng file test này. Sửa bằng cách đệm `baseMs = _realMs + 5 phút` — đảm bảo MỌI mốc giả lập (kể cả `nowMs=0`) luôn lớn hơn đồng hồ thật với biên độ dư dả, loại bỏ hoàn toàn khả năng đọc nhầm đồng hồ thật. Đã chạy lại `flutter test --exclude-tags slow` 2 lần liên tiếp (899/899 cả 2 lần) để xác nhận hết flaky.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 899/899 pass (ổn định qua 2 lần chạy); `example/flutter analyze` + `flutter test --exclude-tags slow` 46/46 pass (không đổi gì trong `example/`). CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart snapshot` đã regenerate (`EnergyRegenResult` — class mới duy nhất được gate track; 2 hàm top-level `regenEnergy`/`offlineEarnings` không khớp regex quét symbol của gate do format nhiều dòng, không phải vấn đề — class đã đủ để gate nhận diện có API mới và đòi hỏi CHANGELOG, đã có).

**Tự chấm điểm:** 9.5/10 — đúng yêu cầu "Đề xuất" ở mức nghiêm ngặt nhất có thể (cross-check bằng CÙNG 1 hàm, không phải công thức tương đương), phát hiện đúng khoảng cách giữa "hàm xác định" và "hàm pure độc lập" trước khi code thay vì code sai rồi sửa, bắt và sửa đúng 1 lỗi timing tinh vi chỉ lộ khi chạy full suite (đã verify hết flaky qua 2 lần chạy), 3 lớp test đầy đủ (pure math, simulation logic, cross-check + subprocess thật), không over-engineer (bỏ qua đúng 2 phần "không bắt buộc"/ngoài AC — debug overlay panel và weighted_random_pick).
