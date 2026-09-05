---
id: BUG-04
title: FlameAudio.audioCache.prefix hardcode ghi đè static toàn cục
type: bug
priority: P2
effort: M
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

## Đề xuất fix
Không dùng `AudioCache` global singleton cho asset riêng của package — tạo
`AudioCache` instance riêng (`AudioCache(prefix: '...')`) chỉ cho
`AudioManager` dùng nội bộ, để `FlameAudio.audioCache`/`bgm` mặc định của app
không bị đụng.

## Acceptance criteria
- [ ] App dùng `roy_casual_kit` + tự phát SFX riêng từ asset của mình không bị lỗi path.
- [ ] Nhạc nền `bkg.ogg` của package vẫn phát đúng như cũ.
