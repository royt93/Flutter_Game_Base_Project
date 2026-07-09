---
id: w28-2-social-viral
title: "Social/Viral: share, invite, rate app"
wave: 28
phase: 2
status: todo
owner: claude
---

# Phase 2 — Social/Viral

## Vì sao (audit)

Grep toàn repo `lib/`: không tìm thấy `share`/`invite`/`referral`/`rate` chức năng
tiêu biểu nào. `app_translations.dart` (503 key, 22 ngôn ngữ) không có key nào tiền
tố `share_`/`invite_`/`rate_`. Game có leaderboard offline (Wave 21.6) nhưng không
có đường ra ngoài app (share kết quả, mời bạn, nhắc đánh giá store) — gap hoàn toàn
cho organic growth.

## Phạm vi đề xuất

1. Share kết quả: nút chia sẻ ở dialog Win (campaign) + dialog kết thúc side-mode
   (score/stage đạt được) — dùng package `share_plus` (chưa có trong `pubspec.yaml`,
   cần `flutter pub add`).
2. Rate app: nhắc đánh giá store sau mốc gắn kết (ví dụ sau khi thắng level 10 hoặc
   đạt streak N ngày), không nhắc lại nếu đã bấm "đã đánh giá"/"không, cảm ơn" — lưu
   cờ qua `StorageKeys`.
3. Invite: cân nhắc scope nhỏ (share link app store đơn giản) vì referral tracking
   thật cần backend — game hiện offline-first, không có server.

## Việc cần làm khi bắt đầu

- [ ] `flutter pub add share_plus` (kiểm tra license/kích thước phù hợp).
- [ ] Thêm key i18n `share_*`/`rate_*` cho 22 ngôn ngữ (theo quy ước `_extraByLang`).
- [ ] Thêm `StorageKeys` mới cho cờ "đã nhắc rate"/"đã bấm không".
- [ ] Test widget cho nút share/rate xuất hiện đúng dialog, không chặn input khác.
- [ ] Verify máy thật: share sheet mở đúng, không crash khi cancel share.
