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
- [x] submitScore/topN hoạt động đúng, tự sắp xếp giảm dần theo score, cắt đúng ở cap đã cấu hình.
- [x] Kết quả topN() map trực tiếp được sang LeaderboardEntry không cần transform thêm ở phía caller.
- [x] Test: submit nhiều điểm, xác nhận thứ tự đúng, cắt đúng khi vượt cap, và submit điểm thấp hơn cap hiện tại không lọt vào topN.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. **N/A**: pure `GetxService`, không có UI/widget nào (xem `## Quyết định`).
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. **N/A**: không có widget.

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

## Quyết định

Implement `LocalScoreboardService extends GetxService` tại `lib/core/local_scoreboard_service.dart`, export qua `lib/roy_casual_kit.dart`.

**API:** `LocalScoreboardService({capacity = 50})`, `submitScore(playerLabel, score)`, `topN(n) -> List<LeaderboardEntry>`.

**Mô hình dữ liệu — "arcade high-score table", không dedupe theo player:** mỗi lần `submitScore` là 1 dòng độc lập trong bảng, kể cả cùng 1 `playerLabel` submit nhiều lần (đọc sát nghĩa "top N điểm" trong Đề xuất, không phải "top N người chơi"). Nếu 1 game cụ thể muốn "chỉ giữ điểm cao nhất mỗi người", có thể tự lọc phía caller trước khi gọi `submitScore` — giữ service đơn giản, không đoán trước policy đó (ponytail: không thêm option chưa được yêu cầu).

**Tie-break xác định (quyết định kỹ thuật quan trọng nhất):** ban đầu định dùng `nowMsClamped()` làm tie-break (giống các service khác dùng "clamped clock" chống lùi đồng hồ), nhưng nhận ra 2 lệnh `submitScore` gọi liên tiếp trong cùng 1 test/frame có thể rơi cùng 1 millisecond thật — khiến kết quả sắp xếp không xác định (flaky). Đổi sang 1 bộ đếm `sequence` tăng dần đơn thuần (không phụ thuộc đồng hồ), lưu kèm mỗi entry và phục hồi đúng qua `max(sequence đã lưu) + 1` khi hydrate lại từ instance mới — vừa xác định 100%, vừa không cần bảo vệ chống lùi đồng hồ (thứ tự chỉ dùng để tie-break hiển thị, không phải cơ chế thưởng có thể bị khai thác qua vặn giờ).

**Không có UI/widget mới** — cùng lý do như IDEA-29: "Đề xuất" chỉ mô tả API service, câu animation/reducedMotion trong checklist là boilerplate chung của template task, không áp dụng.

**Test:** `test/core/local_scoreboard_service_test.dart`, 16 test case — validation (empty/blank label, negative score, score 0 hợp lệ, capacity <= 0 throw assert), topN sorting/rank (rỗng, n <= 0, sắp xếp giảm dần + rank 1-based, format `fmtNum`, n > số entry hiện có, tie-break theo thứ tự submit, cùng player submit nhiều lần không dedupe), capacity cap (cắt đúng khi vượt cap, điểm thấp hơn mọi entry trong cap đầy bị loại ngay), persist/corrupt (bỏ qua entry hỏng khi hydrate, reload đúng qua instance mới, burst 10 lần `submitScore` không await giữa các lần vẫn ghi đúng toàn bộ).

**Gate API-compatibility:** class mới → thêm mục CHANGELOG.md dưới `## 0.2.0`, chạy `dart run tool/api_compatibility.dart snapshot` để cập nhật `tool/api_snapshot.json`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 815/815 pass (16 test mới + toàn bộ suite cũ không bị phá), `example/flutter analyze` sạch (không đổi gì trong `example/`). Không cần device smoke test thật (không có UI).

**Tự chấm điểm:** 9.5/10 — đúng yêu cầu "Đề xuất", tái dùng chặt chẽ convention/pattern đã có (`AchievementService`/`DailyQuestService`/`VersionedJsonStore`/`fmtNum`), phát hiện và xử lý đúng 1 rủi ro flaky-test tiềm ẩn trước khi nó xảy ra (tie-break theo sequence thay vì mốc thời gian thật), test bao phủ đủ mọi case kể cả cap/tie-break/persist, không over-engineer (không thêm dedupe-per-player hay highlight param không được yêu cầu).
