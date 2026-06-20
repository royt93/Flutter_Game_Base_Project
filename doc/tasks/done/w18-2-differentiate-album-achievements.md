---
id: w18-2-differentiate-album-achievements
title: Khác-biệt-hoá Album & Thành tựu
wave: 18
phase: 2
status: todo
owner: claude
---

# Phase 2 — Album & Thành tựu: khác-biệt-hoá (hết "2 hệ claim-mốc-xu na ná")

## Vấn đề hiện tại (audit)
- **Album (Collection)**: điểm thắng first-clear → claim ô → xu/booster + sticker.
- **Thành tựu (Achievements)**: chỉ số lifetime chạm ngưỡng → claim → xu.
Cả hai = "đạt mốc → claim xu". Sticker Album hiện chỉ là hình, không tác dụng.

## Thiết kế mới — chia VAI rõ ràng
### Album = sưu tập có TÁC DỤNG (collectible + perk nhẹ)
- Mỗi sticker mở khoá tặng **perk cosmetic/QoL nhẹ** (KHÔNG p2w): vd khung avatar, màu
  trail gem, +1 hint/ngày, mở 1 skin gem. Hoàn thành 1 BỘ (set) → thưởng lớn 1 lần.
- Bỏ thưởng "xu" lặp ở Album → chuyển sang giá trị SƯU TẬP + perk.

### Thành tựu = cột mốc DANH DỰ (badge/title, ít xu)
- Giữ mốc lifetime nhưng thưởng chính = **danh hiệu/badge** (hiện ở Home/Versus), xu chỉ
  tượng trưng. Thêm danh hiệu hiển thị cạnh tên.

→ Album = "đẹp + tiện ích nhẹ", Thành tựu = "khoe thành tích". Không còn trùng "claim xu".

## Triển khai
- `collection_controller.dart` + `collection.dart`: gắn `perk`/`set` cho sticker; áp
  perk qua `ActiveCosmetics`/settings.
- `achievement_controller.dart`: thêm `title`/`badge`, giảm xu, wire hiển thị danh hiệu.
- UI: Album hiện perk khi mở; Thành tựu hiện danh hiệu đang đeo.
- i18n cho perk/title.

## Test
- Sticker mở → perk áp đúng; hoàn set → thưởng 1 lần (không lặp).
- Thành tựu → danh hiệu mở/đeo đúng; xu giảm theo thiết kế.
- Không double-reward; `resetProgress` sạch; first-clear anti-farm giữ nguyên.

## Lưu ý
- Perk PHẢI không-p2w (cosmetic/QoL) để giữ công bằng leaderboard.
- Liên quan: [[cosmetics-active-holder]], [[balance-economy-principles]].
