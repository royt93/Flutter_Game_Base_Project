# I13 — SFX pop cao độ theo cỡ nhóm (wire playMelodic vào gameplay)

**Epic:** Cảm giác/A-V · **SP:** 2 · **Pri:** P1 · **Deps:** none

## Mục tiêu
Phát âm thanh (nốt nhạc ngũ cung, cao độ tăng theo combo/màu) mỗi khi pop 1 nhóm gem — hiện tại pop không phát bất kỳ SFX nào.

## Vì sao
`AudioManager.playMelodic`/`playNote`/`noteIndexFor` (`lib/core/audio_manager.dart` dòng 99-190) đã xây dựng đầy đủ hệ ngũ cung + màu-là-giọng + hợp âm wombo, có test thuần (`noteIndexFor` không phụ thuộc Flutter) — nhưng **grep toàn `lib/game/pop_star_game.dart` không có bất kỳ lệnh gọi `AudioManager` nào**. Hạ tầng nhạc lý đã xong, chỉ chưa wire vào gameplay thật — đây là việc "nối dây", không phải xây mới.

## Acceptance criteria
- [ ] Mỗi lần pop hợp lệ (`_tryPop` tìm được nhóm `>=2`) gọi `AudioManager.to.playMelodic(combo: ..., colorIndex: ..., keyIndex: ...)`
- [ ] `combo` tăng theo chuỗi pop liên tiếp trong 1 lượt cascade (nếu game đã track combo/chain ở đâu đó thì tái dùng, không tạo counter trùng); nếu chưa có, dùng `group.length` làm proxy hợp lý cho "cỡ nhóm" thay vì combo-chain
- [ ] `colorIndex` truyền đúng màu vừa pop (0-based theo `colorGrid` value)
- [ ] `keyIndex` có thể cố định 1 hoặc map theo world (tuỳ quyết định khi implement — không bắt buộc phức tạp hoá nếu 1 giá trị cố định đã đủ hay)
- [ ] Không phát âm khi tap trượt (không nhóm hợp lệ)
- [ ] `flutter analyze` 0 lỗi

## Subtasks (gợi ý file)
- `lib/game/pop_star_game.dart` — import `AudioManager`, gọi `Get.find<AudioManager>().playMelodic(...)` (hoặc alias sẵn có nếu `AudioManager` expose singleton getter kiểu `.to`) ngay tại điểm tính `group.length`/màu trong `_tryPop`, trước `_clearAndCollapse`.
- Kiểm tra `AudioManager` đã `Get.put(..., permanent: true)` ở `main.dart` (đã có theo CLAUDE.md) — chỉ cần `Get.find`.
- Test: gọi `_tryPop` (hoặc `handleTap`) trong widget test, xác nhận không crash khi audio muted/unmuted (không cần assert phát đúng file mp3 — khó test qua `FlameAudio` thật).

## Ghi chú kỹ thuật
Đọc kỹ toàn bộ comment nhạc lý ở đầu `playMelodic` (dòng 106-142) trước khi wire — tránh gọi sai tham số làm mất hiệu ứng "màu = giọng, combo = leo bậc" đã thiết kế sẵn.

DoD chung: ../README.md.
