---
id: ENH-95
title: "Audio mix preferences và focus policy"
type: enhancement
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/audio_manager.dart` (volume constants 38-43, init 148-159, lifecycle 173-207, `playSfx` 226); `lib/core/storage_service.dart` `StorageKeys`; `example/lib/screens/settings_screen.dart:115-123` sound toggle.

## Hiện trạng

Audio chỉ có `muted` persisted; BGM volume hardcode 0.35/duck 0.08, SFX volume do từng caller truyền. Settings chỉ toggle sound, không có slider/profile. Lifecycle pause/resume có nhưng không có focus policy (duck/pause từ platform focus) và chưa đảm bảo restore đúng user-volume.

## Vì sao cần / Hậu quả

Player không chỉnh được mix BGM/SFX; duck/focus có thể restore sai volume custom; game casual thường cần âm lượng riêng.

## Đề xuất

Persist `bgmVolume`/`sfxVolume` clamp 0..1, tương thích key mute cũ. Mute là gate orthogonal, không phá volume saved. Pause/resume/duck restore user volume. No-backend vẫn không throw. Settings thêm slider có semantics.

## Acceptance criteria

- [ ] Unit fake player: clamp/persist/reload BGM+SFX volume.
- [ ] Mute cũ vẫn tương thích, unmute restore volume user.
- [ ] Duck/focus/pause/resume restore đúng user volume khi overlap.
- [ ] Widget settings test slider + semantics.
- [ ] No-backend path không throw.

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

Cao. Đã đọc `audio_manager.dart`: `_bgmVolume`/`_bgmDuckedVolume` const, init chỉ hydrate `audioMuted`; settings dòng 115-123 chỉ `CandyToggleSwitch`. Không trùng ENH-79 pool, IDEA-45 ducking, IDEA-67 haptic sync.
