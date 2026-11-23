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

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `WaveSchedule` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. CHỈ làm sau FEAT-215 và FEAT-217 (xem chỉ mục backlog); phát hành phần lịch, không có thực thể/AI.
- [ ] 4. Test `advance` lớn không bỏ sót/trùng spawn, cùng seed cho cùng chuỗi, save giữa chừng (`toJson/fromJson`) rồi tiếp tục cho cùng kết quả, `count/interval <= 0` là `ArgumentError`.
- [ ] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Không bỏ sót hay trùng spawn dù `dt` lớn.
- [ ] Tiếp tục sau khôi phục cho kết quả y hệt chạy liền.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`
