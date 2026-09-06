---
id: FEAT-23
title: weightedRandomPick<T>() — util random có trọng số cho loot-table/reward
type: feature
priority: P2
effort: S
source: user pick (chốt trong phiên chọn util mới)
---

## Vì sao cần
Reward/loot-box/gacha cần random có trọng số (item hiếm tỉ lệ thấp hơn item
thường) — hiện code chỉ dùng `Random()` rời rạc từng chỗ
(`neon_bg.dart:46`, `reward_popup.dart:49`), không có hàm dùng chung, mỗi
tính năng reward mới (FEAT-06 Achievement, FEAT-09 Offline earnings) sẽ phải
tự viết lại logic này.

## Đề xuất phạm vi
```dart
T weightedRandomPick<T>(List<T> items, List<double> weights, {Random? random});
```
Validate `items.length == weights.length` (assert debug-only, không throw ở
release). Không cần hỗ trợ "loại trừ sau khi rút" (sampling without
replacement) ở bản đầu — ghi rõ giới hạn này trong doc comment.

## Yêu cầu test
- **Unit test**: seed `Random` cố định, verify phân phối kết quả qua N lần
  lặp xấp xỉ đúng tỉ lệ trọng số (thống kê, không cần chính xác tuyệt đối);
  case 1 phần tử trọng số 100% luôn ra đúng phần tử đó; case trọng số 0 không
  bao giờ được chọn.

## Demo
Không cần demo UI riêng (thuần logic) — có thể minh hoạ gián tiếp khi
FEAT-06/FEAT-09 dùng tới.

## Acceptance criteria
- [ ] Test thống kê xác nhận trọng số ảnh hưởng đúng tỉ lệ chọn (không phải phân phối đều).
- [ ] `items.length != weights.length` → assert rõ ràng ở debug, không crash mù mờ.
