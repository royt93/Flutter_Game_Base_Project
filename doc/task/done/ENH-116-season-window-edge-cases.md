---
id: ENH-116
title: "SeasonEventService.currentWindow: RangeError với length khổng lồ, và cửa sổ sai khi anchor ở tương lai"
type: enhancement
layer: lib/core
priority: P3
effort: S
source: "Survey thời gian 2026-11-23 (test tạm chạy thật, đã xoá)"
---

## Bằng chứng (đo bằng test tạm trên VM)

1. `currentWindow('ev', length: Duration(days: 100000000), cooldown: Duration.zero)` ném `RangeError` (`DateTime.fromMillisecondsSinceEpoch` vượt ±8.64e15 ms). `length`/`cooldown` có thể đến từ remote config; `ArgumentError` hiện chỉ chặn `<= 0` / âm. Theo quy ước BUG-112/ENH-85: nên validate trần rõ ràng thay vì để `RangeError` thoát ra.
2. Anchor ở tương lai (chỉ vào được qua save restore/cloud từ máy có đồng hồ nhanh, vì anchor mới luôn lấy từ `nowMsClamped`): `elapsed ~/ cycleMs` làm tròn về 0, không phải xuống, nên với `-cycleMs < elapsed < 0` cửa sổ báo `isActive: false` dù theo chu kỳ lùi lại thì đang trong cửa sổ trước đó (vd chu kỳ 14 ngày, length 7 ngày, now = anchor - 10 ngày: đáng lẽ active, báo không). Với anchor +100 ngày: cửa sổ trả về bắt đầu +2 ngày (inactive), sau đó chạy đúng chu kỳ. Ảnh hưởng nhỏ, chỉ khi anchor tương lai.

## Đo và thấy ổn (không cần task)

- `PersistentCooldownService`: end-time xa tương lai (400 ngày) báo đúng `running` còn 399 ngày (không lỗi, nhưng một bản restore có end-time lạ khoá cooldown tới đó trừ khi game gọi `cancel`); entry sai kiểu/âm/null được bỏ qua (ready); vặn đồng hồ tiến 30 ngày rồi lùi: cooldown cũ hết (ready), `clockRewindBlockedCount` tăng, cooldown mới sau đó vẫn 60 phút theo đồng hồ đã kẹp (đúng hành vi ClampedClock đã ghi trong tài liệu).
- Vặn đồng hồ tiến 60 ngày với season: cửa sổ nhảy sang chu kỳ sau và kẹt ở đó khi lùi lại (cùng hành vi ClampedClock; `TrustedClockService` là lựa chọn cho phần thưởng một lần).

## Đề xuất

(1) validate `length + cooldown` có trần (vd <= vài chục năm) bằng `ArgumentError`; (2) dùng chia sàn (`(elapsed / cycleMs).floor()`) cho elapsed âm. Cả hai đều Behavior change nhỏ, cần test + CHANGELOG.

## Kết quả thực hiện (2026-11-23)

- Phần 1 làm: `currentWindow` ném `ArgumentError` khi `length + cooldown` > 100 năm (`SeasonEventService.maxCycleMs`). 1 test mới (gồm sát trần vẫn chấp nhận); mutation (bỏ kiểm tra) làm 1 test đỏ.
- Phần 2 KHÔNG làm, thông tin đo ban đầu sai ý: test BUG-66 đã quy định anchor tương lai = "sự kiện chưa bắt đầu" (window bắt đầu đúng anchor, `isActive=false`). Dùng chia sàn sẽ phá hợp đồng đó và hiện sự kiện sắp tới là đang diễn ra. Tôi đã thử, test BUG-66 đỏ, owner chọn giữ BUG-66. Còn lại: anchor tương lai XA (>1 chu kỳ) cho cửa sổ chưa mở trong vài chu kỳ, là hệ quả của cùng hợp đồng.
- Root 4137 pass, analyze sạch, API gate unchanged, 4 quality-gate tool pass (performance_budget exit 255 một lần khi chạy song song, chạy lại riêng thì PASS).
