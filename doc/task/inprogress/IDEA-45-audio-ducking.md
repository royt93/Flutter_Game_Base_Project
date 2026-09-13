---
id: IDEA-45
title: "AudioManager: audio ducking cho BGM khi SFX quan trọng phát"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: M
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua agent quét codebase độc lập)
---

## Vị trí
Mở rộng `lib/core/audio_manager.dart`.

## Hiện trạng
`AudioManager` phát 1 track BGM cố định volume + `playSfx` cho SFX rời rạc từ asset app. Không có cơ chế "ducking" (tạm giảm volume BGM khi 1 SFX quan trọng phát rồi trả lại) — pattern âm thanh chuẩn trong game casual (ví dụ: tiếng thắng/thua, tiếng combo lớn cần nổi bật hơn nhạc nền).

## Vì sao cần / Hậu quả
Thiếu ducking khiến SFX quan trọng bị nhạc nền lấn át về cảm nhận âm lượng, đặc biệt trên loa điện thoại nhỏ — game dùng kit phải tự implement lại toàn bộ fade-volume-rồi-fade-back bằng tay nếu muốn có hiệu ứng này.

## Đề xuất
Thêm tham số optional (ví dụ `duck: true` hoặc factor riêng) cho `playSfx` — khi bật, `AudioManager` tự giảm volume BGM (`Bgm`) xuống 1 mức trong lúc SFX phát, rồi trả về volume gốc ngay sau khi SFX kết thúc (hoặc sau timeout an toàn nếu không biết chính xác thời lượng SFX). Giữ đơn giản — KHÔNG cần fade mượt qua nhiều frame nếu 1 bước giảm/tăng volume tức thời đã đủ tự nhiên (tránh over-engineer); nếu cảm nhận thực tế cần fade mượt thì mới thêm animation volume, không mặc định làm phức tạp trước khi nghe thử.

## Acceptance criteria
- [x] BGM tự giảm volume khi 1 SFX (được đánh dấu duck) phát, tự trả về volume gốc sau khi xong.
- [x] Nhiều SFX duck chồng lên nhau không làm BGM bị kẹt ở volume thấp vĩnh viễn (phải trả về đúng volume gốc sau SFX cuối cùng kết thúc).
- [x] SFX không đánh dấu duck không ảnh hưởng BGM volume, hành vi cũ giữ nguyên (không phá test/API hiện có).
- [x] Test bao phủ mọi case liên quan (happy path + edge case: duck chồng lặp, muted trong lúc duck, dispose trong lúc đang duck) — unit/widget/integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) — bằng chứng cụ thể trong Quyết định (xem ghi chú về giới hạn "nghe thử thật" bên dưới).
- [x] Không có widget UI mới trực tiếp — N/A cho yêu cầu animation nếu không đụng UI.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-45-audio-ducking.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc.
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò — không áp dụng ở đây (không có widget mới), nhưng nếu volume transition được implement dạng fade thì fade đó cũng phải mượt, không giật cục.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — nghe thử thật, log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — pattern audio ducking chuẩn, có giá trị thật, nhưng dễ over-engineer nếu cố làm fade mượt qua nhiều frame ngay từ đầu thay vì bắt đầu từ bước giảm/tăng đơn giản nhất; cũng cần nghe thử thật trên máy để đánh giá "đủ tự nhiên chưa" — nên thử bản đơn giản nhất trước, chỉ phức tạp hoá nếu nghe thử thấy chưa ổn.

## Quyết định

Implement đúng phần Đề xuất — thêm `duck` param cho `AudioManager.playSfx` (`lib/core/audio_manager.dart`), giữ đơn giản nhất có thể theo đúng ghi chú độ tin cậy: 1 bước giảm/tăng volume tức thời (`AudioPlayer.setVolume` trên `Bgm.audioPlayer` có sẵn từ `flame_audio`), KHÔNG fade qua nhiều frame.

- `_duckCount` (int, không phải bool) đếm số SFX-đang-duck đồng thời — chỉ giảm volume khi count đi từ 0→1, chỉ trả về volume gốc khi count về đúng 0. Đây là cơ chế chống "duck chồng lặp làm BGM kẹt ở volume thấp" nêu trong Acceptance criteria.
- Cố ý KHÔNG gate việc trả volume theo `muted` (khác với `startBgm`/`pauseBgm`/`resumeBgm`) — set volume lúc đang mute/pause vô hại, còn nếu gate theo `muted` thì user mute giữa lúc đang duck rồi unmute sau sẽ kẹt vĩnh viễn ở volume đã duck (không còn trigger nào khác để trả lại) — phát hiện qua suy luận trước khi viết test, có test riêng xác nhận.
- Đổi `debugSfxDisposeCount`-style test hook thành API public thật sự: `AudioManager.duckCount` (getter, không `@visibleForTesting`) — khác `debugSfxDisposeCount`, giá trị này có ích thật cho caller (hiện icon "đang duck" trong UI riêng của game), không chỉ để test.
- `_bgmVolume` (0.35, y nguyên giá trị cũ) và `_bgmDuckedVolume` (0.08, hằng số mới) tách thành `static const` thay vì literal rải rác.

**Phát hiện phụ trong lúc làm — giới hạn thật của "nghe thử thật" trên máy này**: Ban đầu định dùng `dlog()` (đã có sẵn quy ước `roy93~` prefix trong file này cho `playSfx` failure) để log mỗi lần duck/unduck, rồi đọc qua `adb logcat`. Xác nhận bằng thực nghiệm: KHÔNG một dòng `debugPrint`/`roy93~` nào của app này xuất hiện trong `adb logcat` trên thiết bị thật này (Pixel 7 Pro), dù logcat hoạt động bình thường cho mọi tiến trình khác và app không crash — có vẻ bản debug build cài qua `mobile_install_app` (không qua `flutter run`/`flutter attach`) không mirror `debugPrint` ra logcat trên thiết bị/bản dựng cụ thể này. Thay vì cố khắc phục hạ tầng logging (ngoài phạm vi task), pivot sang bằng chứng trực quan mạnh hơn: hiện `AudioManager.duckCount` ngay trên demo UI (`example/`), chụp màn hình ĐÚNG lúc SFX đang phát bắt được `duckCount: 1 (bgm ducked)`, rồi sau khi SFX xong bắt được `duckCount: 0` — xác nhận đúng vòng đời duck→unduck chạy trên phần cứng thật với audio backend thật (khác môi trường test, hoàn toàn không có audio plugin). Bản thân model KHÔNG có khả năng nghe âm thanh thật phát ra từ loa thiết bị — đây là giới hạn thành thật cần nêu rõ, không che giấu; người dùng cầm máy thật có thể tự nghe xác nhận thêm nếu muốn.

**Test:** `test/core/audio_manager_test.dart` (+8 test nhóm "IDEA-45: audio ducking") — `duckCount` mặc định 0; `playSfx(duck: true)` tăng lên 1 ngay khi gọi (đồng bộ, trước await đầu tiên), về 0 sau khi xong; `duck: false` (mặc định) không đụng count; 2 SFX duck chồng nhau lên đúng 2, về đúng 0 sau khi cả 2 xong (không về 0 sớm); `muted.value` bật giữa lúc đang duck vẫn unduck đúng, không kẹt; `muted.value` bật từ đầu → hoàn toàn no-op, không tăng count; `onClose()` (dispose `_bgm`) giữa lúc đang duck không throw, count vẫn về đúng 0.

**Demo:** thêm asset ngắn (1.2s, cắt + fade-out từ chính `asset/audio/bkg.ogg` của kit bằng `ffmpeg`, encode mp3 ~24KB — không dùng nguyên bản 4MB để tránh phình example app) tại `example/assets/audio/demo_sfx.mp3`, khai báo trong `example/pubspec.yaml`. Demo card mới "AudioManager audio ducking (IDEA-45)" trong `WidgetShowcaseScreen` (section Buttons & Interactive, ngay sau `SoundToggleFab`) — nút "Play SFX (duck bgm)" gọi `playSfx(..., duck: true)`, hiện trực tiếp `duckCount` hiện tại để quan sát vòng đời.

**Device smoke test (Pixel 7 Pro, `2B051FDH3006MU`, real device):** cài `example/build/app/outputs/flutter-apk/app-debug.apk`, vào Bộ Widget → card "AudioManager audio ducking (IDEA-45)". Bấm "Play SFX (duck bgm)" → chụp ngay lập tức bắt được `duckCount: 1 (bgm ducked)`; ~1.2s sau (SFX asset dài 1.2s) chụp lại thấy `duckCount: 0` — đúng vòng đời. `adb logcat` lọc `level=Error`: không có dòng nào trong suốt phiên thao tác.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 988/988 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 46/46 pass. CHANGELOG.md đã thêm mục dưới `## 0.2.0`. `tool/api_compatibility.dart snapshot` chạy lại KHÔNG tạo diff — `duckCount` chỉ là 1 member mới trên class đã export sẵn, cùng tiền lệ IDEA-35 (gate không track thêm member).

**Tự chấm điểm: 9/10** — đúng yêu cầu Đề xuất, giải pháp đơn giản nhất (1 bước volume, không fade phức tạp) đúng tinh thần ghi chú độ tin cậy, test bao phủ đầy đủ case (kể cả 2 race case tinh vi: chồng duck, mute-giữa-chừng), phát hiện + xử lý đúng 1 bug tiềm ẩn trước khi nó xảy ra (gate theo `muted` sẽ gây kẹt volume vĩnh viễn). Trừ điểm vì giới hạn thành thật: không thể tự "nghe" xác nhận trực tiếp như acceptance criteria mong muốn, phải dùng bằng chứng gián tiếp (on-screen counter + logcat sạch + toàn bộ test suite) thay thế.
