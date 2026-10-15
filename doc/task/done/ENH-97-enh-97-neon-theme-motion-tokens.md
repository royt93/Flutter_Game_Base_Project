---
id: ENH-97
title: Motion Tokens tập trung trong NeonTheme (Duration, Curve, reducedMotion)
type: enhancement
priority: P0
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Hiện tại các widget tự hardcode Duration(200..900ms) và Curves riêng rẽ, thiếu quy chuẩn thiết kế chuyển động thống nhất, gây khó khăn cho việc tinh chỉnh nhịp độ và tối ưu giảm chuyển động cho partner.

## Đề xuất phạm vi
Định nghĩa NeonTheme.motionFast (150ms), motionDefault (250ms), motionDeliberate (400ms), motionCelebrate (800ms) cùng curvePop (easeOutBack), curveSurface (easeOut), curveSmooth (easeInOut). Cung cấp helper NeonTheme.motionDuration(context, base) tự động trả Duration.zero khi reducedMotion bật.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [x] **Unit test**: Kiểm tra giá trị các tokens và hàm motionDuration trả đúng Duration.zero khi reducedMotion=true, trả base khi reducedMotion=false.
- [x] **Widget test**: Widget dùng motionDuration tự động chuyển scale/slide tức thời khi MediaQuery(disableAnimations: true).
- [x] **Integration test**: SettingsScreen bật Reduce Motion -> các widget trong showcase phản hồi tức thì trên thiết bị thật.

## Yêu cầu hiệu năng & Animation
- [x] **60 FPS & Resource cleanup**: Zero allocation, const tokens, không rebuild thừa.
