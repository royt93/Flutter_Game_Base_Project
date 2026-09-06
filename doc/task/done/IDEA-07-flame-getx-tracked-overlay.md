---
id: IDEA-07
title: "FlameTrackedOverlay — bridge Flame Vector2 <-> Flutter Offset"
type: idea
priority: exclusive
effort: L
source: agy
---

## Ý tưởng
1 component cho phép bất kỳ widget Flutter nào (`TooltipBubble`,
`CurrencyCounter`, `StreakCounter`...) bay bám dính chính xác theo vị trí 1
entity trong Flame `GameWidget` (chuyển đổi toạ độ world `Vector2` sang toạ độ
màn hình `Offset`), không giật lag, không lệch tỉ lệ khi resize.

## Vì sao khác biệt
Đây là điểm đau kỹ thuật thật của mọi game kết hợp Flame + Flutter UI (HP bar,
damage number bay lên). Gắn liền với FEAT-14 (Flame starter template) — chỉ
có ý nghĩa sau khi kit thực sự có ví dụ Flame chạy được.

## Phụ thuộc
Nên làm sau FEAT-14.
