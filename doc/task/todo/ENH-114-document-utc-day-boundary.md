---
id: ENH-114
title: "Ngày của kit là ngày UTC: ghi rõ cho consumer, không đổi hành vi"
type: enhancement
layer: docs, lib/core (doc comments)
priority: P3
effort: S
source: "Khảo sát số học/thời gian 2026-11-23; owner chọn chỉ ghi nhận và tài liệu hoá, không đổi hành vi"
---

## Bằng chứng (đã đo bằng chương trình và số học chính xác)

- `todayEpochDayClamped()` = `(UTC ms + debug offset) ~/ 86400000` (`lib/core/utils/clamped_clock.dart:90`), tức ngày UTC. Dùng bởi `DailyLoginService` (claim và streak), `DailyQuestService` (khoá kỳ ngày và tuần `day ~/ 7`), `SeededChallengeService` (`d$day`, `w${day ~/ 7}`), `smart_reminder_scheduling` (`streakExpiringReminderDelay`).
- Hệ quả trên đồng hồ địa phương: ngày kit đổi lúc **07:00 ở UTC+7**, 19:00 ở UTC-5, 16:00 ở UTC-8, 13:00 ở UTC+13. 23:59 và 00:00 giờ Việt Nam thuộc cùng một ngày kit (không reset lúc nửa đêm).
- Hệ quả nhắc nhở: `streakExpiringReminderDelay` báo trước 4 giờ so với nửa đêm UTC, nên ở UTC+7 nhắc lúc **03:00 sáng** (streak hết lúc 07:00), ở UTC-8 nhắc lúc 12:00 trưa. Đo bằng số học chính xác (`datetime`), không phải suy luận.
- Đây có vẻ là thiết kế chống gian lận giờ (ngày UTC không đổi khi người chơi đổi múi giờ), nhưng không tài liệu nào nói vậy. README chỉ liệt kê `DailyLoginService` và `DailyQuestService`; docstring của `todayEpochDayClamped` chỉ ghi "Days since epoch (UTC)".
- `durationToLocalMidnight` (`lib/core/utils/format.dart`) tính nửa đêm địa phương nhưng không nơi nào trong `lib/` gọi (chỉ README nhắc). Doc của nó nói rõ dùng cho đếm ngược mùa giải; không nối với phần còn lại của kit.
- `SeasonEventService` và `EnergyService` dùng mili giây (`nowMsClamped`), không dùng ranh giới ngày, nên không bị ảnh hưởng.

## Phạm vi (owner chọn: chỉ ghi nhận và tài liệu hoá)

- Thêm đoạn rõ ràng vào README (mục DailyLogin/DailyQuest) và doc comment của `todayEpochDayClamped`, `DailyLoginService`, `DailyQuestService`: ngày là ngày UTC, hệ quả theo múi giờ (bảng ở trên), lý do (chống đổi múi giờ/đồng hồ để claim hai lần), và cách consumer cần reset nửa đêm địa phương thì phải tự quyết.
- Ghi chú về `streakExpiringReminderDelay`: giờ nhắc tính từ nửa đêm UTC, consumer ở múi giờ khác nên cân nhắc `warnBefore` hoặc thời điểm gửi.
- KHÔNG đổi hành vi, KHÔNG đổi API, KHÔNG đổi ranh giới ngày: đổi sẽ làm streak hiện có nhảy một ngày và mở lỗ gian lận đổi múi giờ.

## Ngoài phạm vi (cần quyết định riêng nếu muốn)

- Tuỳ chọn múi giờ cho reset (`resetOffset`, mặc định UTC): thêm API công khai, cần thiết kế cách chuyển streak khi đổi offset và test DST.
- Đổi sang ngày địa phương cho mọi người: rủi ro cao, không nên trước release.

## Acceptance criteria

- [ ] README và 4 doc comment nêu rõ ngày UTC và bảng hệ quả theo múi giờ; không đổi code logic.
- [ ] Một test khoá hành vi (để doc không lệch): ranh giới ngày tại 00:00 UTC bất kể múi giờ; hai thời điểm khác múi giờ cùng ngày UTC cho cùng ngày kit.
- [ ] Không đổi API công khai (`tool/api_compatibility.dart check` giữ nguyên); `flutter analyze` sạch.
- [ ] Audit >9/10.

## Kết quả thực hiện

- Audit / điểm:
- Tests:
- Commit/push:
