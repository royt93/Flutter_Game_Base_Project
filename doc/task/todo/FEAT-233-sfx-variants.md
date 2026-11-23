---
id: FEAT-233
title: "AudioManager.playSfxVariant: chọn một trong N tệp có seed, tránh lặp liền kề; đổi cao độ là phần riêng cần thử thiết bị"
type: feature
layer: lib/core
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm

`AudioManager.playSfx(fileName, {volume, duck})` phát đúng một tệp qua pool `AudioPlayer`. `audio_manager.dart` không có `playbackRate`/pitch (grep không khớp). `SeededRandom.nextInt` có sẵn.

## Chia việc

1. **Chọn biến thể (test host được):** hàm thuần `SfxVariantPicker(files, random)` chọn một tệp, không chọn lại đúng tệp vừa phát khi `files.length >= 2`; `files` rỗng là `ArgumentError`; nhận `Random` (SeededRandom) để tái lập. `AudioManager.playSfxVariant(List<String> files, {volume, duck})` gọi picker rồi `playSfx`. Test: không lặp liền kề qua nhiều lần chọn, tái lập theo seed, một tệp duy nhất vẫn phát; mutation check. KHÔNG đụng logic pool/duck hiện có.
2. **Đổi cao độ nhẹ (CHƯA kiểm chứng):** phụ thuộc `audioplayers` có `setPlaybackRate` trên nền tảng và phiên bản đang dùng; tôi CHƯA kiểm API này trong repo. Chỉ làm sau khi đọc tài liệu `audioplayers` của phiên bản trong `pubspec.lock` và thử trên máy thật (S24U) vì test host không có plugin âm thanh. Nếu không chắc, bỏ phần này.

## Rủi ro

`AudioManager` nhạy với test (ghi chú trong CLAUDE.md: `isE2eTest` bỏ qua init audio). Giữ thay đổi ở mức thêm hàm mới, không sửa `playSfx`.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Phần 1: viết test đỏ cho `SfxVariantPicker` (không chọn lại tệp vừa phát khi >= 2 tệp, một tệp vẫn phát, `files` rỗng là `ArgumentError`, tái lập theo seed).
- [ ] 2. Cài `SfxVariantPicker` thuần Dart + `AudioManager.playSfxVariant` gọi picker rồi `playSfx`; KHÔNG sửa `playSfx`, pool hay duck.
- [ ] 3. Mutation check picker; `flutter test test/core/audio_manager_test.dart` vẫn pass.
- [ ] 4. Phần 2 (tuỳ chọn, CHƯA kiểm chứng): đọc tài liệu `audioplayers` đúng phiên bản trong `pubspec.lock` về `setPlaybackRate`; chỉ làm nếu chắc, và thử trên S24U (test host không có plugin âm thanh). Nếu không chắc, bỏ và ghi lý do.
- [ ] 5. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate; ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Không bao giờ chọn liền kề cùng tệp khi có >= 2 tệp.
- [ ] `playSfx` không đổi hành vi, test cũ pass.
- [ ] Phần đổi cao độ hoặc làm có bằng chứng thiết bị, hoặc ghi rõ không làm.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/audio_manager_test.dart test/core/utils`
