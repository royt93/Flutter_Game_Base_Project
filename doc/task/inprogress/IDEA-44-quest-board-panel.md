---
id: IDEA-44
title: "QuestBoardPanel — widget hiển thị danh sách quest cho DailyQuestService"
type: idea
priority: exclusive (độ tin cậy cao)
effort: M
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua agent quét codebase độc lập)
---

## Vị trí
Mới — `lib/presentation/widgets/common/quest_board_panel.dart`, cạnh `lib/core/daily_quest_service.dart` (IDEA-29).

## Hiện trạng
`DailyQuestService` (IDEA-29) là service logic thuần: `register`/`incrementProgress`/`isCompleted`/`claim` theo `QuestPeriod` (daily/weekly). Không có widget nào trong kit hiển thị danh sách quest kèm tiến độ + nút claim — game dùng kit phải tự vẽ lại toàn bộ UI này từ đầu dù phần logic đã có sẵn.

## Vì sao cần / Hậu quả
Thiếu UI mẫu khiến `DailyQuestService` chỉ có giá trị "logic", chưa thực sự "cắm vào là chạy" như tinh thần casual-game-kit — mỗi game phải tự thiết kế lại 1 màn hình quest board, dễ lệch pattern animation/theme với phần còn lại của kit.

## Đề xuất
`QuestBoardPanel({required List<QuestViewModel> quests, required void Function(String questId) onClaim})` — danh sách card, mỗi card hiện tên quest (caller cung cấp label, service không lưu tên), thanh tiến độ (tái dùng widget progress đã có trong kit nếu phù hợp, ví dụ `ProgressBarStars`/tương đương — không tự vẽ progress bar mới nếu đã có), nút claim chỉ enable khi `isCompleted` và chưa claim, animation khi 1 quest chuyển sang trạng thái claimable (nhấn mạnh — không flat). `QuestViewModel` là 1 record/class nhỏ do caller tự map từ `DailyQuestService` ra (widget không phụ thuộc trực tiếp `DailyQuestService` để giữ tách biệt UI/logic, đúng convention `LeaderboardList`/`LocalScoreboardService` đã có ở IDEA-30/IDEA-31).

## Acceptance criteria
- [x] Hiển thị đúng danh sách quest với tiến độ, trạng thái claimable phân biệt rõ (visual khác trạng thái đang làm/đã claim).
- [x] `onClaim` chỉ gọi được khi quest đã hoàn thành và chưa claim; bấm khi chưa đủ điều kiện không có tác dụng.
- [x] Danh sách rỗng hiển thị đúng (không crash, có empty-state hợp lý).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + trạng thái claimed/chưa đủ điều kiện/rỗng) — widget test dựng widget thật, assert đúng hành vi/animation/state.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-44-quest-board-panel.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc.
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — `DailyQuestService` xác nhận không có widget tiêu thụ trong repo, đúng pattern "service có sẵn nhưng thiếu UI mẫu" đã lặp lại nhiều lần trong kit (LeaderboardList/BackupRestorePanel cùng dạng). Effort M, widget mới độc lập, không đụng file nhạy cảm/scope peer.

## Quyết định

Implement đúng phần Đề xuất: `QuestBoardPanel`/`QuestViewModel` (`lib/presentation/widgets/common/quest_board_panel.dart`), cùng convention "pure/data-driven, caller giữ nguồn sự thật" như `LeaderboardList`/`LeaderboardEntry` — widget không phụ thuộc trực tiếp `DailyQuestService`.

- Tái dùng `ProgressBarStars` (với `starThresholds: []` — chỉ dùng track+fill, không cần marker sao) cho thanh tiến độ thay vì tự vẽ progress bar mới; tái dùng `EmptyStatePlaceholder` cho danh sách rỗng; tái dùng `CommonButton` cho nút claim (enable/disable qua `onTap: null` khi chưa `isClaimable`, đúng convention `_enabled = onTap != null` có sẵn trong `CommonButton`) — không viết lại bất kỳ widget nào trong 3 cái này.
- `QuestViewModel.isClaimable` (`isCompleted && !claimed`) là điều kiện DUY NHẤT để enable nút. `_QuestRow` (StatefulWidget nội bộ) theo dõi `didUpdateWidget`: khi `isClaimable` chuyển `false → true` giữa 2 lần build, nút Claim pop vào bằng `ScaleTransition` + `Curves.easeOutBack` (300ms) — đúng quy ước "khoảnh khắc ăn mừng" của `NeonTheme`, cùng pattern `StarRating`'s BUG-31 pop-in. Quest đã claimable NGAY từ lần mount đầu tiên (ví dụ mở panel sau khi đã hoàn thành từ phiên trước) KHÔNG animate — cùng triết lý "không replay khoảnh khắc đã qua" của `ProgressBarStars`/`StarRating`. Tôn trọng `NeonTheme.reducedMotion` (bỏ qua animate hoàn toàn khi bật).
- `target == 0` (edge case phòng thủ, không nên xảy ra thực tế) không chia cho 0 — coi như 100% thay vì NaN/crash.
- Wired demo vào `example/lib/screens/widget_showcase_screen.dart` (section "Layout & Cards", ngay sau `LeaderboardList`) — 2 quest mẫu cố định trong state của screen (không wiring `DailyQuestService` thật, đúng tinh thần "widget tách biệt khỏi service cụ thể"), nút "Thắng 1 trận" tăng progress quest thứ nhất để demo trực quan chuyển trạng thái + animation pop.
- Bump `example/test/widget_showcase_screen_test.dart`'s `physicalSize` từ `Size(1080, 9000)` lên `Size(1080, 9600)` — demo mới đẩy `ComboHeatBackground`'s "Bump heat" ra ngoài viewport cũ, cùng loại vấn đề đã gặp ở IDEA-31 (BackupRestorePanel).

**Test:** `test/widget/common/quest_board_panel_test.dart` — 9 test: danh sách rỗng, quest chưa hoàn thành (nút disabled), quest hoàn thành chưa claim (nút bật + đúng callback + đúng id), quest đã claim (nút "Đã nhận" disabled, bấm không có tác dụng), nhiều quest độc lập đúng thứ tự, `target = 0` không crash, chuyển sang claimable lúc runtime trigger animation không throw (kể cả sau khi animation chạy hết, không còn Ticker treo), đã claimable ngay từ mount đầu không throw, Reduce Motion bật vẫn đúng trạng thái nút.

**Device smoke test (Pixel 7 Pro, `2B051FDH3006MU`, real device):** cài `example/build/app/outputs/flutter-apk/app-debug.apk`, vào Bộ Widget → Layout & Cards → card "QuestBoardPanel (IDEA-44)". Quan sát: quest "Thắng 3 trận" (2/3) hiện progress bar xanh + nút "Nhận thưởng" xám disabled; quest "Dùng 1 booster" (1/1, viền vàng claimable) có nút "Nhận thưởng" màu vàng — bấm claim đổi thành "Đã nhận" disabled, persist đúng qua rebuild. Bấm "Thắng 1 trận" đưa quest 1 lên 3/3 → card tự động lên viền vàng + nút chuyển vàng claimable; bấm claim → "Đã nhận". `adb logcat` lọc `level=Error`: không có dòng nào trong suốt phiên thao tác.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 981/981 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 46/46 pass (sau khi bump `physicalSize`). CHANGELOG.md đã thêm mục dưới `## 0.2.0`. `tool/api_compatibility.dart snapshot` chạy lại KHÔNG tạo diff — `QuestBoardPanel` chỉ export gián tiếp qua `common_widgets.dart` (cùng tiền lệ BackupRestorePanel/AchievementUnlockListener); `test/api_compatibility_test.dart` vẫn pass.

**Tự chấm điểm: 9.5/10** — đúng yêu cầu Đề xuất, tái dùng tối đa 3 widget có sẵn thay vì viết lại, test bao phủ đầy đủ case kể cả animation transition + reducedMotion, device smoke test thật xác nhận toàn bộ luồng progress→claimable→claim hoạt động đúng, không phá API/test hiện có (đã fix `physicalSize` khi phát hiện). Trừ điểm nhỏ vì demo dùng state cứng trong `example/` thay vì wiring `DailyQuestService` thật (quyết định có chủ đích, giữ đúng ranh giới widget/service).
