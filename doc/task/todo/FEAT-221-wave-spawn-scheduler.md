---
id: FEAT-221
title: "Wave/spawn scheduler thuần Dart (lịch spawn theo thời gian và wave, seeded, bám GameClock)"
type: feature
layer: lib/core
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Quét `lib`: không có spawner/wave. Cần cho shooter, tower defense, survival; kết hợp `pooled_component` (đã có) và `GameClock`.

## Phạm vi đề xuất

- `WaveSchedule` thuần Dart: danh sách wave, mỗi wave có danh sách `SpawnEntry(kind, count, interval, startOffsetMs)`; `advance(dtSeconds)` trả danh sách spawn đến hạn; `SeededRandom` cho biến thiên; `currentWave`, `isFinished`; `toJson/fromJson` để lưu giữa chừng.
- Validate bằng `ArgumentError` (count/interval > 0); dữ liệu từ remote config qua `SdkResult`.
- Test: thứ tự spawn theo thời gian, `advance` lớn (không bỏ sót, không trùng), tái lập với cùng seed, lưu rồi tiếp tục cho cùng kết quả; mutation check.

## Rủi ro đã nêu

Gần FEAT-215/217, dễ phình thành engine. Làm SAU hai task đó và chỉ phát hành phần lịch, không có thực thể/AI.

## Câu hỏi mở

Spawn theo thời gian tuyệt đối hay theo "khi wave trước hết kẻ địch". Đề xuất: thời gian trước; điều kiện hết kẻ địch do game phát sự kiện `nextWave()` thủ công.
