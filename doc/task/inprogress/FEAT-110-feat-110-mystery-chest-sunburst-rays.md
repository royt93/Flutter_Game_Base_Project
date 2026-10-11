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
- [x] **TECNO integration smoke**: tapped the chest and verified reward reveal on TECNO KJ7. Local shared Gradle cache remained untouched; used isolated `/tmp/roy-gradle-isolated` and Gradle JDK 17 after the default JDK25/cache path failed.
- [x] **Host validation**: root 2937/example 240 tests, analyzers and all quality gates pass.

## Hiệu năng & lifecycle
- [x] Single AnimationController stops at completion and disposes on unmount; ray painter reuses Path/Paint.
- [ ] 60 FPS benchmark: not measured; no sustained-frame claim.
