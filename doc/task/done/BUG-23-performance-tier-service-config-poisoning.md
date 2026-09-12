---
id: BUG-23
title: "PerformanceTierService: cấu hình/mẫu FPS không hợp lệ có thể làm hỏng vĩnh viễn bộ đếm hoặc crash"
type: bug
priority: P3
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/performance_tier_service.dart`.

## Hiện trạng
`windowSize <= 0` có thể để `_window` luôn rỗng, khiến `reduce()` throw khi tính trung bình. Mẫu frame duration NaN/vô cực/âm có thể đầu độc rolling average vĩnh viễn (1 giá trị bất thường làm lệch trung bình mãi mãi vì logic rolling không loại bỏ outlier). Thứ tự threshold (downgrade vs upgrade) và tính hữu hạn của chúng cũng không được kiểm tra.

## Vì sao cần / Hậu quả
1 lần đo frame time bất thường (ví dụ do GC pause cực dài, hoặc lỗi platform trả về giá trị âm) có thể làm hệ thống tier vĩnh viễn nghĩ máy yếu (hoặc mạnh) sai, ảnh hưởng tới quyết định bật/tắt shader layer trang trí cho phần còn lại của session.

## Đề xuất
Validate `windowSize > 0` và threshold hữu hạn + downgrade < upgrade trong constructor (ném `ArgumentError` nếu sai — đây là lỗi cấu hình lập trình viên, không phải input runtime thật). Bỏ qua (không đưa vào rolling window) mẫu frame duration không hữu hạn/âm thay vì để nó đầu độc trung bình.

## Acceptance criteria
- [x] Constructor throw rõ ràng với windowSize <= 0 hoặc threshold không hữu hạn/sai thứ tự.
- [x] Mẫu frame duration NaN/Infinity/âm bị bỏ qua, không ảnh hưởng tới rolling average.
- [x] Test: windowSize 0/âm, threshold NaN/Infinity/đảo ngược, mẫu frame duration âm/NaN/Infinity liên tiếp.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Quyết định
Làm đúng như Đề xuất, không thêm gì khác: constructor validate 4 điều
kiện (windowSize > 0; downgrade hữu hạn + >= 0; upgrade hữu hạn + >= 0;
downgrade < upgrade — điều kiện cuối đảm bảo tier luôn có khả năng hồi
phục, không kẹt vĩnh viễn ở low nếu 2 threshold trùng/đảo ngược).
`recordFrameMs()` bỏ qua (không thêm vào `_window`) mẫu không hữu hạn
hoặc âm, trả về `false` (không đổi tier) cho mẫu bị từ chối.

Xác nhận không có caller nào trong repo tự truyền `FrameBudgetTracker(...)`
với tham số tuỳ chỉnh (chỉ `PerformanceTierService` tự tạo bằng default),
nên đổi sang throw không phá call site nào.

Test: 9 test mới — windowSize 0/âm, downgrade NaN/âm, upgrade
Infinity/âm, downgrade==upgrade/downgrade>upgrade, và mẫu
NaN/Infinity/âm liên tiếp không đầu độc rolling average (verify bằng 3
mẫu hợp lệ tiếp theo vẫn tính đúng, tier vẫn high). Tổng 20 test, tất cả
pass. `flutter analyze` sạch cả root + `example/`. `flutter test
--exclude-tags slow`: tất cả pass, không regression.

Không có device smoke test — pure logic tracker (không phụ thuộc
SchedulerBinding thật theo CLAUDE.md), không render UI trực tiếp.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-23-performance-tier-service-config-poisoning.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — service này là pure logic (không phụ thuộc SchedulerBinding thật theo CLAUDE.md) nên rất dễ test, effort thấp. Ảnh hưởng thực tế nhỏ (chỉ quyết định bật/tắt shader trang trí, không phải core gameplay) nên priority P3.
