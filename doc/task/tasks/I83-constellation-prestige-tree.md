# I83 — Sky Shrine thành skill tree cho Prestige — NG+ có chiều sâu

**Epic:** E8 Enhance · **SP:** 8 · **Pri:** Should
**Deps:** [[I82]] nên làm trước (tránh 3 hệ buff cùng lúc)
**Mở rộng:** [[I64]] [[I27]]
**Trạng thái:** ✅ Done (2026-08-13) — **đi đường gộp, SP 3 thay vì 8**

## Hiện trạng
**Prestige (I27)** hiện là: reset `unlockedLevel` về 1, `prestigeTier++`,
+1000 coin, target score nhân theo tier. Chơi lại đúng 260 màn cũ, khó hơn.
Không có gì mới để mở khoá, không có quyết định nào để ra.

**Sky Shrine (I64)** hiện là: Star Seed, constellation claim được, aura đổi
màu nền. Thuần trang trí.

Hai hệ vanity cạnh nhau, mỗi hệ thiếu đúng thứ hệ kia có.

## Đề xuất
Constellation trở thành **skill tree cho New Game+**:
- Star Seed vẫn kiếm như cũ.
- Mỗi constellation, khi hoàn thành, cho một perk nhỏ **chỉ có tác dụng từ
  prestige tier ≥1**.
- Tier càng cao, mở được càng nhiều nhánh — nhưng target cũng nặng hơn theo
  công thức `prestigeTargetScore` đã có.

Kết quả: vòng NG+ trở thành "build của tôi cho lần chạy này" thay vì "y hệt
lần trước nhưng khó hơn".

## Vì sao Should (và vì sao SP 8)
Đây là task có **đòn bẩy cao nhất nhưng rủi ro cao nhất** trong E8. Nó chạm
cân bằng của toàn bộ 260 màn ở mọi tier, và tương tác với perk (F14) + pet
passive ([[I82]]) — ba hệ buff cùng lúc.

Nếu sprint chỉ đủ chỗ cho 2 trong 3 (I81/I82/I83), **bỏ cái này**.

## User story
*As a* người chơi đã hoàn thành campaign *I want* lần chạy NG+ khác lần
trước *so that* prestige là lý do chơi tiếp, không phải bài tập lặp.

## Acceptance criteria
- [ ] Perk constellation **chỉ** hiệu lực khi `prestigeTier >= 1`. Ở tier 0
      chúng hiện ra dạng xem trước (khoá), tạo động lực prestige.
- [ ] Số perk mở được cùng lúc bị giới hạn theo `prestigeTier` — chốt bảng
      trong `constellations.dart`, không rải công thức.
- [ ] Người chơi **chọn** nhánh nào kích hoạt (đây là chỗ ra quyết định).
      Đổi được ngoài ván chơi, giống khuôn `perks_screen`.
- [ ] Không perk nào áp dụng ở mode dùng best-score — cùng lý do và cùng
      khuôn với [[I82]].
- [ ] Trần cứng khi cộng dồn với perk F14 + pet passive: chốt và test một
      "kịch bản max build" để bảo đảm nó không phá `levels_achievability_test`
      theo hướng ngược lại (màn dễ tới mức 3 sao tự động).
- [ ] Prestige tier ≥1 với 0 perk chọn vẫn phải **thắng được** — bảng cân
      bằng không được giả định người chơi có perk.
- [ ] `_load()` re-validate id constellation đã chọn theo bảng const hiện tại.
- [ ] i18n 22 ngôn ngữ; test cho bảng giới hạn theo tier + loại trừ side-mode.

## Subtask
1. `constellations.dart` — thêm perk cho mỗi constellation + bảng
   `tier → số nhánh mở được`.
2. `game_controller.dart` — state nhánh đang kích hoạt (persist + re-validate),
   nối vào các điểm buff. **Tái dùng đúng điểm nối mà [[I82]] đã dựng**, đừng
   mở đường thứ ba.
3. `sky_shrine_screen.dart` — chọn/bỏ chọn nhánh, hiện trạng thái khoá ở tier 0.
4. Sweep cân bằng: chạy achievability ở tier 0, 1, 3 với build rỗng và build max.
5. i18n + test.

## Rủi ro
- **Ba hệ buff chồng nhau** (perk F14 + pet I82 + constellation I83) không ai
  hiểu nổi. Giảm bằng: làm I82 trước, dùng chung điểm nối, và một màn hình
  duy nhất hiện tổng buff đang có hiệu lực.
- **Cân bằng NG+** rất khó tune bằng tay qua 260 màn × nhiều tier. Dựa vào
  `levels_achievability_test.dart` chạy tự động ở nhiều tier, đừng chơi tay.

## Ghi chú
Nếu sau khi phác thảo thấy nó biến thành hệ thứ ba nói cùng điều với F14,
cân nhắc phương án rẻ hơn: **gộp** constellation vào chính hệ perk có sẵn
(constellation mở thêm slot perk / mở perk mới), thay vì dựng cây kỹ năng
riêng. Đường đó SP 3 thay vì 8 và đạt được phần lớn giá trị.

DoD chung: `../README.md`.

---

## Quyết định: KHÔNG dựng cây kỹ năng riêng

Phác thảo xong lộ ra đúng thứ mục "Ghi chú" của task đã lường. Đối chiếu hai
bảng hiệu ứng đang có:

| Hệ | Hiệu ứng |
|---|---|
| `PerkEffect` (F14) | `extraUndo`, `moveHint`, `coinBonus` |
| `PetPassive` ([[I82]]) | `extraUndo`, `extraHint`, `coinBonus` |

**Trùng nhau.** Hệ thứ ba nói lại cùng ba điều đó là nhiễu thuần tuý, và người
chơi phải tự cộng ba nguồn buff trong đầu — đúng rủi ro số 1 mà task tự ghi.

Nên đi đường rẻ đã được task cho phép: **constellation mở thêm perk vào chính
hệ F14**. Tái dùng nguyên `activePerkIds`, `togglePerk`, `PerksScreen`. Không
có đường buff thứ ba, không có màn hình thứ hai để chọn perk. SP thực tế ~3.

## Đã làm

- `constellations.dart` — `kPrestigePerks` (4 perk, mỗi constellation mở 1),
  `kPerkSlotsByPrestigeTier` (bảng, không phải công thức rải rác),
  `perkSlotsForPrestigeTier`, `unlockedPrestigePerks`.
- `perks.dart` — 4 giá trị `PerkEffect` mới.
- `game_controller.dart` — `allUnlockedPerks`, `perkSlots`, `hasPrestigePerk`;
  `togglePerk` dùng trần động; `_load` re-validate id **và** kẹp theo trần.
- `perks_screen.dart` — perk prestige nằm chung danh sách, chưa mở thì hiện
  "Prestige để mở khoá" thay vì ẩn (động lực prestige mà AC yêu cầu).

### 4 perk và vì sao chọn đúng 4 hiệu ứng đó

| Perk | Chòm sao | Hiệu ứng | Điểm nối sẵn có |
|---|---|---|---|
| Sao Thương Nhân | Phoenix (20★) | booster rẻ 15% | `_buy` — choke point duy nhất |
| Nở Bụi Sao | Dragon (60★) | +2 Star Dust mỗi 3 sao | 2 chỗ cộng star dust |
| Trời Nghệ Nhân | Pegasus (120★) | craft point ×1.5 | ngưỡng craft |
| Bình Minh Thứ Hai | Serpent (200★) | cơ hội thứ hai đầu màn miễn phí | `buySecondChance` ([[I88]]) |

**Cả 4 đều thuộc kinh tế/tiện ích, KHÔNG chạm điểm số.** Đây là chốt an toàn
quan trọng nhất: AC lo cả hai chiều (màn bất khả thi **lẫn** màn dễ tới mức 3
sao tự động). Hiệu ứng không đổi điểm thì `levels_achievability_test` giữ
nguyên kết quả ở mọi tier — không phải tune tay qua 260 màn × nhiều tier, đúng
thứ mục "Rủi ro" của task cảnh báo.

Có test chốt tính chất này (`mọi hiệu ứng prestige đều thuộc kinh tế/tiện ích`):
ai thêm hiệu ứng chạm điểm buộc phải sửa ca đó, và khi ấy phải chạy lại
achievability ở mọi tier.

## Kiểm chứng

- `test/data/prestige_perks_test.dart` — **30 ca**: bảng dữ liệu (không trùng
  id/hiệu ứng với F14), bảng ô theo tier (đơn điệu, không ngoại suy vô hạn,
  tier âm), mở khoá (tier 0 chỉ xem trước), chọn perk, hiệu lực từng perk, loại
  trừ mode best-score, save hỏng.
- `levels_achievability_test.dart` — 260/260 xanh.
- **Mutation-check 5/5 bị bắt:** bỏ gate `prestigeTier >= 1`; ngoại suy slot vô
  hạn; bỏ loại trừ mode best-score; bỏ re-validate khi nạp; trần perk quay về
  cứng 2.
- Toàn bộ suite: **1334 xanh**, `flutter analyze` 0 issue.

## Lỗ test tự tìm ra và đã vá

Mutation "trần perk quay về cứng 2" **ban đầu không bị bắt**: ca "không bật quá
số ô" boot ở tier 0 (đúng 2 ô) nên không phân biệt được với bản hard-code. Đã
thêm ca boot ở tier 1 bật thật >2 perk.

## Nợ đã ghi, không giấu

1. **Perk F14 vẫn chạy ở mode best-score.** `hasPrestigePerk` loại trừ, nhưng
   `hasPerk` (F14) thì không — hành vi có từ trước I83, cố ý không đổi trong
   task này vì nó ảnh hưởng kỷ lục đã lưu của người chơi hiện tại. Đáng mở task
   riêng để quyết định.
2. i18n mới en + vi; 20 ngôn ngữ còn lại rơi về bản en qua `_extraEn`.
3. ~~Chưa verify trên thiết bị thật.~~ Đã verify trên Pixel 7 Pro với save gieo
   sẵn (prestige tier 3, 210 sao): màn Bảo bối hiện `Ô perk: 0/4` đúng bảng
   tier, đủ 4 perk prestige mở khoá kèm mô tả đã dịch, và 3 perk F14 nằm chung
   một danh sách — không có màn hình thứ hai.
