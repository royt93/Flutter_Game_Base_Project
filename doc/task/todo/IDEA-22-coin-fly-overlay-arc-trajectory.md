---
id: IDEA-22
title: "CoinFlyOverlay bay đường thẳng tuyệt đối — quỹ đạo cong + scale pop sẽ 'xịn' hơn hẳn"
type: idea
priority: P3
effort: M
source: Claude, audit UI/animation polish round 6 (parallel fork C)
---

## Ý tưởng
`CoinFlyOverlay._WheelSpinnerState.build()`'s vị trí đồng xu tính bằng
`Offset.lerp(widget.from, widget.to, t)!` — nội suy tuyến tính thuần giữa
2 điểm, nghĩa là mỗi đồng xu bay theo 1 đường thẳng tuyệt đối từ điểm xuất
phát tới đích, chỉ khác nhau về thời điểm bắt đầu (stagger). Không scale,
không xoay, không cong quỹ đạo trong suốt hành trình.

## Vì sao cần
Hiệu ứng "coin fly" ở hầu hết game casual chất lượng cao (Candy Crush,
Coin Master, ...) luôn bay theo quỹ đạo cong (parabol/cubic bezier, thường
vọt lên rồi rơi xuống đích) kèm scale nhấp nhô — đường thẳng tuyệt đối đọc
là "cứng"/"máy móc" hơn hẳn so với phần còn lại của kit vốn đã khá chỉn chu
về juice (`RewardPopup`'s confetti burst, `StarRating`'s pop-in).

## Đề xuất
Thay `Offset.lerp` bằng 1 đường cong bậc 2 (quadratic bezier) qua 1 điểm
kiểm soát ở giữa, đẩy lên trên (vd `controlPoint = Offset.lerp(from, to,
0.5)! - Offset(0, height * 0.3)`), công thức
`B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2`. Đồng thời thêm scale nhẹ (1.0 →
1.2 → 0.9, "squash" lúc đáp) đồng bộ theo `t` để đồng xu có cảm giác nảy
lên trước khi rơi vào đích, thay vì trôi thẳng đều đều.

## Acceptance criteria
- [ ] Đồng xu bay theo quỹ đạo cong (không còn là đường thẳng `Offset.lerp` thuần).
- [ ] Có scale pop nhẹ trong lúc bay (tôn trọng `reducedMotion` — tắt hẳn phần cong/scale, giữ nguyên logic `onArrive`/`onDone` timing hiện có).
- [ ] Test xác nhận vị trí tại `t` giữa hành trình khác với `Offset.lerp` tuyến tính thuần (chứng minh quỹ đạo thực sự cong).
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — hiệu ứng rõ ràng đáng làm cho tinh thần "xịn sò hơn" người
dùng yêu cầu, nhưng effort cao hơn các ENH khác trong round này (đổi công
thức nội suy vị trí, cần tinh chỉnh độ cong/scale bằng mắt trên thiết bị
thật để "cảm" đúng, không chỉ đúng toán học).
