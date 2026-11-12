---
id: BUG-107
title: "StreakShieldCard tràn 32px ngang ở màn 320dp"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-200 pha 2: viewport sweep 2026-11-12"
---

## Vị trí
`lib/presentation/widgets/common/streak_shield_card.dart:194` (Row `spaceEvenly` chứa các cột metric `Current Streak` / shield, nội dung không co giãn).

## Tái hiện (đã chạy)
`runViewportSweep` với `StreakShieldCard(streakDays: 14, shieldCount: 2, ...)` ở 320x480: `A RenderFlex overflowed by 32 pixels on the right.` Các viewport khác (360x640, landscape, tablet) đạt.

## Hướng sửa
Bọc từng cột metric trong `Expanded`/`Flexible` hoặc dùng `Wrap`; giữ nguyên hình ảnh ở màn rộng (không đổi golden nếu có thể). Kiểm text scale 2.0 sau khi sửa.

## Tiêu chí xong
Bỏ `skip` của test `StreakShieldCard` trong `viewport_sweep_test.dart`, sweep xanh; nếu golden `streak_shield_card_*` đổi thì regenerate bằng quy trình artifact.
