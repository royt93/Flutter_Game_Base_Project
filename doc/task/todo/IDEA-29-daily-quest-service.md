---
id: IDEA-29
title: "DailyQuestService — hệ thống nhiệm vụ hàng ngày/tuần độc lập với AchievementService/DailyLoginService"
type: idea
priority: exclusive
effort: M
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/core/achievement_service.dart`, `lib/core/daily_login_service.dart`.

## Hiện trạng
`AchievementService` là tiến độ vĩnh viễn (không reset) do caller khai báo; `DailyLoginService` chỉ theo dõi streak đăng nhập, không phải nhiệm vụ tuỳ ý ("thắng 3 trận", "dùng 1 booster"). Casual game gần như luôn cần 1 cơ chế THỨ BA: bộ nhiệm vụ caller khai báo, tự reset theo ngày/tuần, claim độc lập với 2 cơ chế kia. Hiện tại team phải tự xây từ đầu trên `VersionedJsonStore`.

## Vì sao cần / Hậu quả
Thiếu cơ chế này buộc mỗi game tự phát minh lại logic reset-theo-ngày (dễ sai, đặc biệt phần chống lùi đồng hồ mà `ClampedClock` đã giải quyết sẵn cho các service khác).

## Đề xuất
`DailyQuestService extends GetxService` — `register(id, targetCount)` (giống `AchievementService.register`), `incrementProgress(id, amount)`, `claim(id)`, lưu qua 1 `VersionedJsonStore` blob keyed theo `todayEpochDayClamped()`/tuần trong năm để tự reset không cần cron job, cùng đảm bảo chống lùi đồng hồ như `DailyLoginService`.

## Acceptance criteria
- [ ] register/incrementProgress/claim hoạt động đúng, tự reset đúng chu kỳ ngày/tuần dựa trên ClampedClock (không dùng DateTime.now() trực tiếp).
- [ ] Chống lùi đồng hồ: vặn đồng hồ hệ thống lùi lại không cho phép re-claim nhiệm vụ đã claim hoặc reset sớm hơn dự kiến.
- [ ] Test: register/increment/claim happy path, claim khi chưa đủ target (từ chối), reset đúng khi sang ngày/tuần mới, và test chống lùi đồng hồ.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-29-daily-quest-service.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — nhu cầu rõ ràng và phổ biến trong casual game, có sẵn pattern tương tự (`AchievementService`/`DailyLoginService`) để tham chiếu convention, giảm rủi ro thiết kế sai.
