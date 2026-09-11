---
id: ENH-32
title: "ProgressBarStars' star marker snap outline→filled, không pop — khác StarRating cùng icon sao"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork C)
---

## Vị trí
`lib/presentation/widgets/common/progress_bar_stars.dart` — vòng lặp vẽ
marker:
```dart
for (final t in starThresholds)
  Positioned(
    ...
    child: Icon(
      p >= t ? Icons.star_rounded : Icons.star_outline_rounded,
      ...
    ),
  ),
```

## Hiện trạng
`StarRating` (cùng icon `Icons.star_rounded`, cùng ý nghĩa "đạt mốc sao")
có hiệu ứng pop-in `ScaleTransition` + `Curves.easeOutBack` khi 1 sao được
"earned". `ProgressBarStars`' marker chỉ đổi `IconData`/`color` tức thì khi
`progress` vượt ngưỡng `t` — không transition nào, dù đây là chính xác
cùng 1 khoảnh khắc "đạt mốc sao" mà `StarRating` đã xử lý đẹp.

## Vì sao cần
2 widget dùng chung icon sao cho cùng 1 ý nghĩa nhưng khác hẳn cảm giác:
1 bên có "pop" thoả mãn, 1 bên chỉ snap. Đây là điểm không nhất quán rõ
ràng nhất trong nhóm Progress & Reward.

## Đề xuất
Khi `p` vượt qua 1 ngưỡng `t` (chuyển từ chưa đạt → đạt), chạy 1
`AnimationController` ngắn (~300ms, `Curves.easeOutBack`) scale sao đó từ
0.6 → 1.0, giống hệt kỹ thuật `StarRating` đã dùng — có thể tái dùng luôn
`StarRating` làm marker thay vì `Icon` trần nếu muốn tối giản code (một
`StarRating` với `total: 1` cho mỗi marker), hoặc tự thêm 1
`TweenAnimationBuilder` riêng theo dõi việc "vừa đạt mốc".

## Acceptance criteria
- [x] Marker sao pop nhẹ (scale bounce) đúng lúc `progress` vượt ngưỡng, không pop khi mount lần đầu đã đạt sẵn (tránh pop tất cả sao cùng lúc lúc khởi tạo).
- [x] `reducedMotion` bật → không animation.
- [x] Test xác nhận marker chuyển trạng thái đúng, có/không animation theo `reducedMotion`.
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Quyết định
Chuyển `ProgressBarStars` sang `StatefulWidget`, 1 `AnimationController`
riêng mỗi threshold (`Map<double, AnimationController>`, tạo lười qua
`putIfAbsent`, value mặc định 1.0 — không pop lúc mount dù ngưỡng đã đạt
sẵn). `didUpdateWidget` so `oldP`/`p` (đã clamp) với từng threshold, gọi
`forward(from: 0.0)` đúng cho threshold VỪA vượt qua. Cùng pattern
`AnimationController` tường minh đã dùng ở ENH-31 (không dùng
`TweenAnimationBuilder` + key trick). Verify: `flutter analyze` sạch +
`flutter test` 466 pass ở root, 29 pass ở `example/`. Device smoke Pixel 7
Pro thật: không crash/exception khi bấm "+20% progress" nhiều lần liên
tiếp (vượt qua cả 3 ngưỡng sao).
