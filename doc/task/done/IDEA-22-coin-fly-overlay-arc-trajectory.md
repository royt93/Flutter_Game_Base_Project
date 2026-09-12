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
- [x] Đồng xu bay theo quỹ đạo cong (không còn là đường thẳng `Offset.lerp` thuần).
- [x] Có scale pop nhẹ trong lúc bay (tôn trọng `reducedMotion` — tắt hẳn phần cong/scale, giữ nguyên logic `onArrive`/`onDone` timing hiện có).
- [x] Test xác nhận vị trí tại `t` giữa hành trình khác với `Offset.lerp` tuyến tính thuần (chứng minh quỹ đạo thực sự cong).
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — hiệu ứng rõ ràng đáng làm cho tinh thần "xịn sò hơn" người
dùng yêu cầu, nhưng effort cao hơn các ENH khác trong round này (đổi công
thức nội suy vị trí, cần tinh chỉnh độ cong/scale bằng mắt trên thiết bị
thật để "cảm" đúng, không chỉ đúng toán học).

## Quyết định
Làm đúng đề xuất, tách thành 2 pure function top-level (theo đúng
convention `confettiOffsetAt`/`confettiRotationAt` đã có trong
`confetti_overlay.dart` — pure, test được không cần dựng widget):
`coinArcOffsetAt(from, to, t, {arcHeight})` (quadratic bezier qua control
point = midpoint kéo lên `arcHeight` px) và `coinScaleAt(t)` (1.0 → 1.2
đỉnh ở t=0.5 qua `Curves.easeOut` → 0.9 lúc t=1 qua `Curves.easeIn`).
`arcHeight` tính theo `(to - from).distance * 0.3` — tỉ lệ theo khoảng
cách bay thay vì hằng số cố định, để quỹ đạo cong hợp lý dù `from`/`to`
gần hay xa nhau.

Phát hiện toán học đáng chú ý khi viết test: vì control point's dx luôn
đúng bằng trung điểm dx của from/to (chỉ dy bị kéo lên), công thức
quadratic bezier's dx suy giảm đại số về ĐÚNG interpolation tuyến tính
(`x0 + t*(x2-x0)`) — nghĩa là quỹ đạo chỉ cong theo trục y, dx luôn trùng
đường thẳng. Test ban đầu so sánh `Positioned.left` (dx) sai vì lý do này,
sửa lại so sánh `Positioned.top` (dy) mới đúng.

Thêm field `_reducedMotion` (đọc trong `didChangeDependencies`, cùng
convention ConfettiOverlay/RibbonBadge/LevelNodeButton) — khi bật, bỏ qua
hoàn toàn `coinArcOffsetAt`/`coinScaleAt`, dùng lại `Offset.lerp` thuần +
scale cố định 1.0, giữ nguyên logic `onArrive`/`onDone` timing (đã tự
collapse về 1 frame từ trước).

Test: 4 test pure function mới + 2 test widget mới (root). `flutter
analyze` sạch cả root + `example/`. `flutter test --exclude-tags slow`:
tất cả pass, không regression (488→494).

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Progress & Reward → CurrencyCounter demo → bấm "Fly +25". Chụp được
ngay 1 khung hình giữa chừng cho thấy nhiều đồng xu đang bay ở các vị trí
lệch nhau theo quỹ đạo (khác hẳn trước — trước đây tất cả bay thẳng hàng
theo 1 đường), số tiền cập nhật đúng 100→125 sau khi hoàn tất, không
exception trong logcat.
