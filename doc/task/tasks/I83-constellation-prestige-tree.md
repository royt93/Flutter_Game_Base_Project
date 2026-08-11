# I83 — Sky Shrine thành skill tree cho Prestige — NG+ có chiều sâu

**Epic:** E8 Enhance · **SP:** 8 · **Pri:** Should
**Deps:** [[I82]] nên làm trước (tránh 3 hệ buff cùng lúc)
**Mở rộng:** [[I64]] [[I27]]
**Trạng thái:** 📋 To Do

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
