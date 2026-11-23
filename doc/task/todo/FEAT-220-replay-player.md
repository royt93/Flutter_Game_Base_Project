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

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `ReplayPlayer` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. Đọc `replay_recorder.dart` (offset đơn điệu, RFC determinism) và `game_time_controller.dart` (`tick`, `GameClock.scale`); ghi vào task ranh giới: kit chỉ phát SỰ KIỆN theo thời gian.
- [ ] 4. Nạp capsule qua đường xác thực sẵn có của `ReplayCapsule`, trả `SdkResult`, không ném; test capsule hỏng/rỗng.
- [ ] 5. Test `seek` lùi/tiến, `advance` lớn vượt nhiều sự kiện (không bỏ sót/trùng), `dt` âm/NaN bị từ chối, tốc độ phát theo `scale`.
- [ ] 6. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 7. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 8. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 9. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Sự kiện cùng offset giữ thứ tự ổn định.
- [ ] `advance` không bỏ sót hay phát trùng sự kiện.
- [ ] Capsule không hợp lệ không làm ném ngoại lệ.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/replay_recorder_test.dart test/core/utils`
