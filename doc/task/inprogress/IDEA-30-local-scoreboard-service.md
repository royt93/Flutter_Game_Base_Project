---
id: IDEA-30
title: "LocalScoreboardService — bảng điểm cao cục bộ, hiện LeaderboardList chỉ là widget hiển thị thuần"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: S
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/presentation/widgets/common/leaderboard_list.dart`, `lib/core/achievement_service.dart`.

## Hiện trạng
`LeaderboardList`/`LeaderboardEntry` thuần hiển thị — theo đúng doc comment của chính nó, "ranking/scoring logic và data đều tới từ app tiêu thụ". Không có service lõi nào thực sự XẾP HẠNG 1 điểm số mới so với các lần chơi trước (bảng điểm cao 1 máy, hữu ích ngay cả trước khi có leaderboard online, và làm cache offline đứng trước 1 backend/Game Center leaderboard thật).

## Vì sao cần / Hậu quả
Mỗi game consumer phải tự tái tạo logic "lưu top N điểm, sắp xếp giảm dần, cắt bớt khi vượt cap" từ đầu — logic đơn giản nhưng lặp lại ở mọi dự án dùng kit.

## Đề xuất
`LocalScoreboardService extends GetxService` — `submitScore(playerLabel, score)`, `topN(int n)` trả về danh sách đã sắp xếp đúng shape `LeaderboardEntry`, lưu qua `VersionedJsonStore<List<...>>` với cap (ví dụ top 50) để giới hạn tăng trưởng storage.

## Acceptance criteria
- [ ] submitScore/topN hoạt động đúng, tự sắp xếp giảm dần theo score, cắt đúng ở cap đã cấu hình.
- [ ] Kết quả topN() map trực tiếp được sang LeaderboardEntry không cần transform thêm ở phía caller.
- [ ] Test: submit nhiều điểm, xác nhận thứ tự đúng, cắt đúng khi vượt cap, và submit điểm thấp hơn cap hiện tại không lọt vào topN.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-30-local-scoreboard-service.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — giá trị hợp lý nhưng độ tin cậy medium (claude ext tự đánh giá) vì phạm vi "xếp hạng cục bộ 1 máy" có thể ít quan trọng hơn nếu game luôn có backend leaderboard thật ngay từ đầu — cân nhắc trước khi làm.
