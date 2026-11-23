---
id: FEAT-218
title: "Demo game thứ hai rất nhỏ trong example (endless runner hoặc merge) để thử kit ở thể loại khác Match-3"
type: feature
layer: example
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog (đề xuất đã nêu là rủi ro phạm vi)"
---

Hiện kit chỉ được chứng minh qua Match-3 Lite, Classic Flame và Sprite Arena. Một game thứ hai khác thể loại sẽ lộ lỗ hổng API sớm (vd thiếu FSM/pathfinding/undo ở FEAT-215/216/217).

## Rủi ro đã nêu

Lệch trọng tâm: owner đã nói demo chỉ cần "sơ sơ", trọng tâm là SDK/widget/helper. Làm SAU FEAT-215/216/217 và chỉ khi một trong số đó cần demo.

## Phạm vi đề xuất

Một màn hình + một engine nhỏ thuần Dart (không Flame, để dùng lại pattern Match-3 và test nhanh), nối GameSessionController/PauseOverlay/EconomyWallet như Match-3. Có test widget + engine; không cần test thiết bị mới ngoài một lượt tay.

## Câu hỏi mở

Thể loại: merge (dùng Grid của FEAT-215) hay endless runner (cần Flame). Đề xuất merge.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. CHỈ bắt đầu sau FEAT-215/216/217 và khi một trong số đó cần demo; xác nhận lại với owner (đã nói demo sơ sơ).
- [ ] 2. Chốt thể loại (đề xuất: merge, dùng `Grid` của FEAT-215) và ghi phạm vi tối thiểu trong "Kết quả thực hiện".
- [ ] 3. Engine thuần Dart + test (cùng cách `Match3Engine`), không Flame ở bản đầu.
- [ ] 4. Màn hình trong `example/lib/screens/`: nối `GameSessionController`, `PauseOverlay`, `EconomyWallet`; thêm lối vào từ `mini_game_hub_screen.dart`.
- [ ] 5. Test widget màn hình (`pump` có thời hạn vì `NeonBg`); một lượt chạy tay trên S24U hoặc ghi rõ chưa chạy.
- [ ] 6. Cập nhật `example/README.md` (bản đồ điều hướng) và cổng cuối example: `cd example && flutter analyze && flutter test --exclude-tags slow`; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Chơi được một vòng (bắt đầu, thắng/thua, lưu).
- [ ] Không thêm API công khai vào package trừ khi một task khác đã chốt.

## Lệnh kiểm chứng nhanh

- `cd example && flutter test`
