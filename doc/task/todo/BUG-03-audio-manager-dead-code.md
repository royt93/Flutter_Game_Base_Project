---
id: BUG-03
title: "AudioManager._ignoreAudio: nhánh dọn dẹp AudioPlayer là dead code"
type: bug
priority: P2
effort: S
verified: true
source: Claude-CLI, verify lại API flame_audio 2.11.14 thật
---

## Vị trí
`lib/core/audio_manager.dart:76-91`

## Vấn đề
`_ignoreAudio` check `value is AudioPlayer` trên kết quả của
`FlameAudio.bgm.play/pause/resume/stop`. Đã verify trong
`flame_audio-2.11.14/lib/bgm.dart`: cả 4 hàm đều trả `Future<void>`, không bao
giờ trả `AudioPlayer`. Điều kiện luôn `false` → toàn bộ logic
`timeout(5s)/dispose` bên trong không bao giờ chạy.

## Hậu quả
Không crash, nhưng ý định "tự dọn player sau khi phát" hoàn toàn vô hiệu — dễ
đánh lừa người đọc code sau này tưởng đã có auto-cleanup.

## Đề xuất fix
Xoá nhánh `if (value is AudioPlayer)` chết, hoặc đơn giản hoá `_ignoreAudio`
thành `unawaited(op.catchError((_) {}))`.

## Acceptance criteria
- [ ] Dead code bị xoá hoặc thay bằng logic thật sự chạy được.
- [ ] `flutter analyze` sạch, test `audio_manager_test.dart` vẫn pass.
