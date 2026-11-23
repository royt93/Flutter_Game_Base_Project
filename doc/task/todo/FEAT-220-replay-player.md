---
id: FEAT-220
title: "Replay player: phát lại ReplayCapsule đã ghi, dừng/tua, bám GameClock"
type: feature
layer: lib/core
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Kit có `ReplayRecorder` (ghi sự kiện với offset đơn điệu từ `start()`), `ReplayCapsule` và `ReproductionCapsule`, nhưng chỉ GHI: không có bộ phát. Game tự phát lại.

## Phạm vi đề xuất

- `ReplayPlayer` thuần Dart: nạp `ReplayCapsule`, `advance(dtSeconds)` (do `GameClock`/`GameTimeController.tick` điều khiển) trả các `ReplayEvent` đến hạn theo thứ tự, `pause/resume`, `seek(offsetMs)` (phát lại từ đầu tới mốc, vì kit không biết trạng thái game), `isFinished`.
- Giữ ranh giới đã ghi trong doc của recorder: kit chỉ phát SỰ KIỆN theo thời gian, deterministic của game là việc của game (RFC trong `replay_recorder.dart`).
- Capsule không tin cậy (import từ ngoài): đi qua đường xác thực sẵn có của `ReplayCapsule`, trả `SdkResult`, không ném.
- Test: thứ tự sự kiện cùng offset ổn định, `advance` lớn vượt nhiều sự kiện, `seek` lùi/tiến, capsule rỗng, `dt` âm/NaN bị từ chối; mutation check.

## Câu hỏi mở

Có hỗ trợ tốc độ phát (bám `GameClock.scale`) ở bản đầu. Đề xuất: có, vì clock đã có `setScale`.
