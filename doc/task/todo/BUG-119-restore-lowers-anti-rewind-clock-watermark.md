---
id: BUG-119
title: "importAll(backup cũ) hạ mốc chống tua đồng hồ (maxMsSeen/maxEpochDaySeen), mở lại việc farm thưởng theo thời gian"
type: bug
layer: lib/core/storage_service + utils/clamped_clock
priority: P1
effort: M
source: "Đợt quét 6 (fork); tôi tự tái hiện độc lập 2026-11-14"
---

## Vấn đề
`ClampedClock` (`nowMsClamped`/`todayEpochDayClamped`) chống "tiến giờ, nhận thưởng, tua giờ lại" bằng mốc `maxMsSeen`/`maxEpochDaySeen` lưu CHÍNH TRONG `StorageService`. `StorageService.importAll` ghi đè toàn bộ store, kể cả mốc đó, bằng giá trị trong backup.

## Tái hiện (đã chạy, test tạm đã xoá)
Sau một lần đọc `nowMsClamped(storage)`, `maxMsSeen = 1794631321837`. `importAll({maxMsSeen: 1000, maxEpochDaySeen: 5})` đặt nó về **1000**. Fork báo thêm: sau đó tua đồng hồ lùi một năm thì `nowMsClamped()` trả về thời gian thấp hơn thật, tức không còn chặn.

## Tác động
Người chơi restore một backup cũ (họ có sẵn, hoặc tự tạo bằng `exportAll` ở thời điểm đầu) rồi chỉnh giờ máy: mốc chống tua giờ về gần 0, mọi hệ thống theo thời gian (energy, offline earnings, daily login/quest, season) dùng lại được như chưa từng bị khoá. `save_integrity` ký backup nên chống sửa tay file, nhưng KHÔNG chống dùng một backup cũ hợp lệ.

## Hướng sửa (cần quyết định chính sách)
`importAll` giữ `max(mốc hiện tại, mốc trong backup)` cho các khoá đồng hồ (`maxMsSeen`, `maxEpochDaySeen`, và nhóm `trusted_clock_*`). Đổi ý nghĩa "restore ghi đè toàn bộ": các khoá này không bao giờ lùi. Câu hỏi: nhóm `trusted_clock_*` (baseline, prevWall, prevMonotonic) là cặp có ý nghĩa cùng nhau, nên chỉ bảo toàn `maxMsSeen`/`maxEpochDaySeen` hay cả nhóm? Cần đọc `trusted_clock.dart` trước khi chọn.

## Tiêu chí xong
Test: sau `importAll(backup cũ)` mốc không thấp hơn trước; một restore bình thường (backup mới hơn) vẫn nâng mốc lên; không làm hỏng test hiện có của `StorageService`.
