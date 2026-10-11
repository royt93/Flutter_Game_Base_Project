---
id: FEAT-110
title: MysteryChest & Sunburst God Rays — Mở rương báu bật nắp & hào quang quay
type: feature
priority: P0
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Khoảnh khắc mở rương báu là trải nghiệm cảm xúc cao nhất của game casual; cần rương rung lắc, nắp bật mở kèm tia hào quang xoay tròn phía sau.

## Đề xuất phạm vi
Widget MysteryChestOpening với trạng thái idle (thở nhẹ) -> shake (rung lắc hồi hộp) -> burstOpen (nắp bật) -> reveal kèm SunburstGodRays xoay tròn phía sau.

## Kiểm thử
- [x] **Unit/widget test**: phase order, tap opens, revealed callback once, repeated activation ignored, Reduced Motion immediate/mid-animation snap, unmount cleanup.
- [x] **Showcase test**: caller-owned reward content appears after reveal.
- [ ] **TECNO integration smoke**: pending; two build attempts failed before test launch with local Gradle cache error `Could not read workspace metadata ... metadata.bin`. No simulator used and no cache deleted.
- [x] **Host validation**: focused chest tests and analyzers pass; full suite/gates pending.

## Hiệu năng & lifecycle
- [x] Single AnimationController stops at completion and disposes on unmount; ray painter reuses Path/Paint.
- [ ] 60 FPS benchmark: not measured; no sustained-frame claim.
