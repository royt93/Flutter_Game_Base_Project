---
id: BUG-04
title: FlameAudio.audioCache.prefix hardcode ghi đè static toàn cục
type: bug
priority: P2
effort: L (nâng từ M — xem ghi chú "CẬP NHẬT sau khi đào sâu")
verified: true
source: agy (Antigravity), verify lại code thật
---

## Vị trí
`lib/core/audio_manager.dart:24`

## Vấn đề
`FlameAudio.audioCache.prefix = 'packages/roy_casual_kit/asset/audio/';` ghi đè
thuộc tính **static** toàn cục của `FlameAudio.audioCache`, dùng chung cho cả
process. Nếu app dùng package này còn muốn phát audio riêng từ thư mục asset
của chính app (`assets/audio/sfx_tap.mp3`), `FlameAudio` sẽ tìm nhầm vào trong
`packages/roy_casual_kit/asset/audio/` và báo lỗi not-found.

## Ghi chú
Giá trị hiện tại là do 1 fix gần đây (`cdd9c9d fix: use packages/roy_casual_kit/
prefix for shader and audio assets`) để chính package tự phát đúng asset của
mình — không phải lỗi phát sinh ngẫu nhiên. Nhưng thiết kế này không scale khi
app cần audio riêng.

## Đề xuất fix — CẬP NHẬT sau khi đào sâu (effort bị đánh giá thấp ban đầu)
Đã thử hướng "tạo `AudioCache` instance riêng cho `AudioManager`" — KHÔNG khả
thi như mô tả ban đầu: đọc source `flame_audio-2.11.14/lib/flame_audio.dart`
xác nhận `FlameAudio.bgm` là `static final Bgm bgm = bgmFactory(audioCache:
audioCache)` — khởi tạo 1 lần duy nhất, dùng chung CHÍNH `FlameAudio.audioCache`
(cùng instance). Tạo 1 `AudioCache` riêng cho `AudioManager` không ảnh hưởng
gì tới `FlameAudio.bgm.play(...)` — vẫn đọc theo `FlameAudio.audioCache.prefix`
toàn cục, nên "fix" kiểu đó chỉ là giả vờ sửa mà không thay đổi hành vi thật.

Muốn scope thật sự đúng cần 1 trong 2 hướng nặng hơn effort M ban đầu:
1. Set `FlameAudio.audioCacheFactory`/`bgmFactory` (2 static field CÓ thể gán
   lại trước lần đầu truy cập `FlameAudio.bgm`/`audioCache`) ngay khi
   `AudioManager` khởi tạo — nhưng vẫn là global, chỉ "thắng" nếu
   `AudioManager` chạm vào `FlameAudio` trước bất kỳ code nào khác của app —
   không giải quyết triệt để, chỉ đổi ai được ưu tiên.
2. Bỏ hẳn `FlameAudio.bgm` (không dùng API `Bgm` của `flame_audio` nữa), tự
   quản lý 1 `AudioPlayer` riêng (từ package `audioplayers` — hiện chỉ là
   transitive dependency qua `flame_audio`, cần thêm trực tiếp vào
   `pubspec.yaml` nếu chọn hướng này) để tự set prefix/asset path độc lập
   hoàn toàn với `FlameAudio`'s global state. Effort thực tế: L, không phải M
   — cần viết lại toàn bộ pause/resume/lifecycle logic hiện đang dựa vào
   `Bgm` của `flame_audio`.

**Quyết định cho vòng fix này:** KHÔNG áp dụng fix nửa vời (giữ nguyên hành vi
hiện tại), để lại task này với effort đã hiệu chỉnh — cần quyết định hướng 1
hay 2 trước khi code, không phải việc "sửa nhanh" như đánh giá ban đầu.

**Cập nhật:** chủ dự án đã xác nhận bỏ qua task này ở vòng fix 12-bug hiện tại
(2026-09-06) — 11/12 bug còn lại đã xong, test xanh, smoke test device PASS,
push riêng không chờ task này. Vẫn giữ trong `todo/`, làm khi có quyết định
hướng 1/2 ở trên.

## Acceptance criteria
- [x] App dùng `roy_casual_kit` + tự phát SFX riêng từ asset của mình không bị lỗi path.
- [x] Nhạc nền `bkg.ogg` của package vẫn phát đúng như cũ.

## Quyết định cuối cùng (2026-09-06)
**Đã sửa**, bằng 1 hướng thứ 3 không có trong phân tích ở trên: `Bgm`
(class của `flame_audio`) nhận `AudioCache` qua constructor
(`Bgm({AudioCache? audioCache})`), không bắt buộc phải là
`FlameAudio.audioCache`. `AudioManager` giờ tự tạo `AudioCache` +
`Bgm` riêng của chính nó (`_cache`/`_bgm`), hoàn toàn không đụng tới
`FlameAudio.audioCache`/`FlameAudio.bgm` toàn cục nữa. Vẫn dùng
`flame_audio`'s `Bgm` (không cần viết lại pause/resume/lifecycle),
không cần thêm dependency `audioplayers` trực tiếp — nhỏ hơn cả 2
hướng đã liệt kê ở trên và sửa dứt điểm, không còn state dùng chung.
Nhận xét trước đó ("tạo AudioCache riêng không ảnh hưởng gì tới
FlameAudio.bgm.play()") vẫn đúng — nhưng chỉ đúng nếu tiếp tục gọi
qua `FlameAudio.bgm`; fix thật là ngừng dùng `FlameAudio.bgm` luôn,
gọi thẳng `_bgm` (instance riêng).

Xác nhận: `test/core/audio_manager_test.dart` có test regression
(`FlameAudio.audioCache.prefix` không bị ghi đè) + test prefix riêng
đúng; `flutter analyze`/`flutter test` xanh (root 318, example 23);
smoke test thật trên iOS Simulator (log
`AudioManager: loaded OK, prefix=packages/roy_casual_kit/asset/audio/`).
