---
id: FEAT-107
title: JuicyFeedback — Tự động đồng bộ Âm thanh + Rung theo preset cho Widget
type: feature
priority: P0
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Hiện tại dev phải tự gọi cả AudioManager và fireHaptic ở mọi nơi, dễ quên hoặc lệch nhịp. Cần 1 giải pháp 1 dòng lệnh tự đồng bộ âm thanh và cảm giác rung.

## Đề xuất phạm vi
Helper JuicyFeedback.trigger(JuicyPreset preset) với các preset: tap, pop, success, warning, chestOpen, coinTick. Tự kiểm tra AudioManager.muted và Haptics.enabled.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra gọi JuicyFeedback.trigger gọi cả AudioManager và fireHaptic đúng preset; không ném lỗi khi service chưa đăng ký.
- [ ] **Widget test**: Gắn JuicyFeedback vào CommonButton onTap, kiểm tra sfx và haptic được kích hoạt đồng thời.
- [ ] **Integration test**: Bấm các nút trong showcase trên thiết bị thật, kiểm tra âm thanh và rung phát ra khớp nhịp bấm.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Không cấp phát object mới khi trigger, tôn trọng cài đặt mute của người chơi.
