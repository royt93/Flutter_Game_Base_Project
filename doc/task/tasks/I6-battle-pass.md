# I6 — Battle-pass mùa (free-track only)

**Epic:** Meta/retention · **SP:** 13 (chẻ nhỏ) · **Pri:** Could · **Deps:** F7 (tái dùng pattern claim mốc)

## Mục tiêu
Track theo mùa (vd 4 tuần/mùa): điểm mùa cộng dồn từ chơi, mốc thưởng free-track
(coin/booster). **Chỉ 1 track free** — không có premium/trả tiền.

## Vì sao
User chọn retention/meta nhưng loại bỏ monetize hoàn toàn — battle-pass ở đây
là track free duy nhất, giữ giá trị "mùa/mốc" mà không đụng IAP.

## Acceptance criteria
- [ ] Season model: `startDate`, danh sách mốc (điểm mùa → coin/booster).
- [ ] Điểm mùa cộng khi thắng level, công thức rõ ràng (không random).
- [ ] Màn hình season progress (tái dùng UI dạng star road F7).
- [ ] Hết mùa → reset điểm mùa, giữ thưởng đã nhận; mùa mới tự bắt đầu theo ngày.
- [ ] Unit test: cộng điểm mùa đúng, claim mốc đúng 1 lần, reset đúng khi qua mùa.

## Subtasks (gợi ý file)
1. `lib/data/` (season config: mốc + startDate).
2. `lib/presentation/controllers/game_controller.dart`: `seasonPoints`,
   `claimedSeasonMask` — tính theo ngày như `claimDaily()`.
3. UI mới hoặc mở rộng shop/home cho season progress.

## Ghi chú kỹ thuật
CHẺ: (a) season points + persist; (b) mốc thưởng + claim; (c) UI. KHÔNG thêm
premium-track — ngoài scope, đã bị loại cùng Option D (monetize).

DoD chung: `../README.md`.
