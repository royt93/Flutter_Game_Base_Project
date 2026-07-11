# F7 — Star road + chest reward

**Epic:** Features · **SP:** 8 · **Pri:** Should · **Deps:** — 

## Mục tiêu
Tổng sao thu được (qua các màn) đổ vào 1 "đường sao"; đạt mốc (vd 5/15/30/50 sao)
→ mở rương thưởng (xu/booster). Meta progression vòng lặp ngoài từng màn.

## Vì sao
Cho sao một "đích đến" thứ 2 (ngoài mở khoá màn) → lý do cày 3-sao, dopamine mốc.

## Acceptance criteria
- [ ] Tổng sao = tổng `star(id)` tốt nhất mọi màn (đọc storage), reactive.
- [ ] Màn hình/әbanner Star Road hiện các mốc + rương (locked/claimable/claimed).
- [ ] Đủ sao mốc → cho mở rương 1 lần (không re-claim sau restart).
- [ ] Mở rương: animation + cộng thưởng (dùng coin fly nếu là xu).
- [ ] Wire `resetState` vào `resetProgress`. Unit test claim/không-re-claim.

## Subtasks (gợi ý file)
1. `lib/core/storage_service.dart`: key `claimedChests` (bitmask/list).
2. Controller: `StarRoadController` (permanent) — `totalStars`, `milestones`, `claim(i)`.
3. UI: `star_road_screen.dart` hoặc banner ở Home/LevelSelect; rương + progress.
4. Reward: xu (coin fly) / booster (+count).
5. Test: `test/presentation/star_road_test.dart`.

## Ghi chú kỹ thuật
Anti re-claim: lưu mốc đã nhận, không phụ thuộc tổng sao hiện tại (tránh reset khi
sao đổi). Bảng mốc + thưởng cấu hình 1 chỗ.

DoD chung: `../README.md`.
