---
id: ENH-24
title: "SegmentedTabBar's pill indicator trượt bằng Curves.easeOut phẳng, cùng vấn đề thiếu overshoot như ENH-23"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork A)
---

## Vị trí
`lib/presentation/widgets/common/segmented_tab_bar.dart` — `AnimatedAlign`
di chuyển pill nền (highlight) giữa các segment, `curve: Curves.easeOut`,
220ms (duration đã tôn trọng `reducedMotion` từ ENH-20, task này chỉ về
curve/cảm giác chuyển động, không phải reducedMotion).

## Hiện trạng
Cùng quan sát như [[ENH-23]] (`CandyToggleSwitch`) — pill nền trượt sang
segment mới rồi dừng lại chính xác không overshoot, cảm giác máy móc hơn
là "candy". Đây là 1 điểm chạm dùng cho lựa chọn quan trọng (độ khó, tab
lọc...) nên đáng đầu tư cảm giác chạm.

## Vì sao cần
Cùng lý do ENH-23 — nhất quán "ngôn ngữ chuyển động" có overshoot đã dùng ở
`NeonDialog`/`RewardPopup` cho các widget chuyển trạng thái tương tác
thường xuyên khác trong kit.

## Đề xuất
Đổi `curve` của `AnimatedAlign` sang `Curves.easeOutBack` (hoặc tương
đương), giữ nguyên duration/logic `reducedMotion` đã có.

## Acceptance criteria
- [ ] `AnimatedAlign`'s curve đổi sang có overshoot.
- [x] Test hiện có (`ENH-17`/`ENH-20`) vẫn pass, không phá logic reducedMotion.
- [x] Device smoke test: chuyển segment vài lần trên máy thật, xác nhận cảm giác nảy nhẹ.

## Quyết định
Làm cùng lúc với ENH-23 như ghi chú tự đề xuất — cùng
`Curves.easeOutBack` cho `AnimatedAlign`'s pill indicator, giữ nguyên
duration 220ms (đã có sẵn, không đổi). Verify: `flutter analyze` sạch +
`flutter test` 448 pass ở root (446+2 mới, gộp với ENH-23), 29 pass ở
`example/` — không phá logic reducedMotion của ENH-20. Device smoke Pixel
7 Pro thật: chuyển tab Easy→Hard, pill trượt đúng vị trí, không lỗi.

## Ghi chú độ tin cậy
Trung bình-cao — cùng mức độ tin cậy [[ENH-23]] (khách quan ở chỗ "hiện
đang phẳng", chủ quan ở chỗ "overshoot bao nhiêu là đủ"). Làm cùng lúc với
ENH-23 nếu muốn 1 curve/giá trị thống nhất cho mọi "slide-to-position"
animation trong kit, tránh mỗi widget 1 con số overshoot khác nhau.
