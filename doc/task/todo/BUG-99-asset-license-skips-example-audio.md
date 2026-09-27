---
id: BUG-99
title: "Asset license checker bỏ sót example audio"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`tool/asset_license_check.dart:21,27-42`; `example/pubspec.yaml:34-36`.

## Hiện trạng

Checker chỉ quét root `asset/`, `shaders/` (const `_assetRoots`). `example/pubspec.yaml` ship `assets/audio/` (`demo_sfx.mp3`, `error.ogg`, `tap.ogg`, `victory.ogg`) và `assets/remote_config/`, không manifest license tương ứng, CI không audit phần này.

## Vì sao cần / Hậu quả

Asset ship thật (audio demo) không qua license gate — rủi ro pháp lý/attribution bị bỏ sót.

## Đề xuất

Mở rộng checker (hoặc script riêng `--root=example`) quét `example/assets/**`, cross-check `example/asset/LICENSES.json` hoặc manifest tương ứng; CI fail khi thiếu entry. Không trùng FEAT-72 (phạm vi 4 root asset).

## Acceptance criteria

- [ ] Fixture mp3 trong example không có manifest entry → check fail.
- [ ] Asset root example có manifest hợp lệ → pass.
- [ ] CI gate chạy cho cả root và example (rõ trong workflow).

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify `_assetRoots = ['asset', 'shaders']` dòng 21 (chỉ root), `example/pubspec.yaml` dòng 34-36 ship `assets/audio/` + `assets/remote_config/`, và `example/assets/audio` chứa `demo_sfx.mp3`, `error.ogg`, `tap.ogg`, `victory.ogg` + `LICENSES.md` (không phải `.json` manifest checker đọc được).
