---
id: FEAT-14
title: Flame game-loop starter template (dependency "chết" hiện tại)
type: feature
priority: P1
effort: M
source: fork nội bộ, verify bằng grep toàn repo
---

## Vấn đề
`pubspec.yaml` khai `flame: ^1.35.1` và `flame_audio: ^2.11.14` làm
dependency, nhưng grep toàn bộ `lib/` và `example/lib/` xác nhận: **không có
1 dòng `FlameGame`/`Component` nào** — `flame_audio` được dùng (qua
`AudioManager`) nhưng `flame` (game engine) hoàn toàn không được chạm tới.
Dialog pattern (`NeonDialog`) trong CLAUDE.md có nhắc tới lý do tồn tại của
dependency này ("nếu consumer app build 1 `GameWidget`") nhưng bản thân
package/example chưa có ví dụ nào.

## Đề xuất (chọn 1)
1. Thêm 1 `RoyGame extends FlameGame` tối giản trong `example/lib/` làm điểm
   khởi đầu thật, chứng minh dependency `flame` có lý do tồn tại và
   `NeonDialog` overlay pattern hoạt động đúng phía trên `GameWidget` thật.
2. Nếu không có kế hoạch dùng Flame thật gần đây, cân nhắc bỏ `flame` khỏi
   `pubspec.yaml` (giữ `flame_audio` vì đang dùng thật) để giảm kích thước
   dependency không cần thiết.

## Acceptance criteria
- [ ] (Hướng 1) `example/` có 1 màn hình chạy `GameWidget(RoyGame())`, có test smoke.
- [ ] (Hướng 2) `pubspec.yaml` không còn `flame` nếu xác nhận không dùng, `flutter analyze` sạch.
