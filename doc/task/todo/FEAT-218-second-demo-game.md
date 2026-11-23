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
