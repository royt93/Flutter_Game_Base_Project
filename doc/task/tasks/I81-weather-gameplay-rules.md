# I81 — `WeatherKind` gắn luật gameplay thật (đang chỉ là skin)

**Epic:** E8 Enhance · **SP:** 5 · **Pri:** Should
**Deps:** — · **Mở rộng:** [[I40]] · **Liên quan:** [[I76]] [[I2]]
**Trạng thái:** ✅ Done (2026-08-12) — **2/3 luật, snow cố ý hoãn**

## Hiện trạng
`worlds.dart` gán mỗi world một `WeatherKind`; `ambient_weather_layer.dart`
vẽ hiệu ứng thời tiết tương ứng. Đó là **toàn bộ** ảnh hưởng của nó — thuần
trang trí, không chạm luật chơi.

Kết quả: 13 world khác nhau về màu sắc và hiệu ứng nền, nhưng chơi **giống
hệt nhau** ngoài việc board to hơn và nhiều màu hơn. Bản đồ thế giới không
có ý nghĩa gameplay.

## Đề xuất
Cho mỗi `WeatherKind` một luật nhẹ, luôn bật ở world tương ứng:

| Thời tiết | Luật đề xuất | Tái dùng cơ chế nào |
|---|---|---|
| Tuyết/băng | tăng nhẹ mật độ ice tile | `_placeIceTilesIfNeeded` đã có |
| Mưa | combo window dài hơn (3.0 → 3.5s) | `activeComboWindowOverride` đã có |
| Nắng | pop nhóm ≥7 thưởng thêm điểm | `scoreForGroup` đã có |
| Gió | 1 ô ngẫu nhiên đổi màu mỗi N nước | cần mới, giữ đơn giản nhất |
| Sương | ô rìa hiện mờ tới khi tap gần | thuần render, không đụng logic |

**Con số trong bảng là điểm khởi đầu, không phải quyết định.** Tune sau khi
chơi thật.

## Vì sao Should
Rẻ và tác động rộng: 13 world tự dưng khác nhau về cảm giác chơi, không cần
thêm level hay mode nào. Gần như mọi luật đều **tái dùng cơ chế đã tồn tại**
(ice, combo override, scoring) — chỉ cần nối dây.

Không Must vì nó đụng độ khó của toàn bộ campaign 260 màn, và ràng buộc
"target achievability" trong CLAUDE.md rất nhạy: bàn không refill nên
`targetScore` chỉ đạt được nếu neo theo số ô. Bất kỳ luật nào giảm số ô khả
dụng đều có thể làm cả một world thành bất khả thi.

## User story
*As a* người chơi đi qua các world *I want* mỗi vùng chơi khác nhau chứ
không chỉ đổi màu *so that* tiến trình cảm thấy như đi tới nơi mới.

## Acceptance criteria
- [ ] Mỗi `WeatherKind` có đúng 1 luật, khai báo **tập trung tại
      `lib/data/worlds.dart`** (cạnh chính `WeatherKind`), không rải điều
      kiện `if (weather == …)` khắp engine.
- [ ] Luật là dữ liệu, không phải code nhánh: cùng khuôn với
      `GauntletModifier` đang dùng cho 3 mode khác nhau (`gauntlet_modifiers.dart`)
      — **tái dùng chính `GauntletModifier`** nếu nó biểu diễn được luật, đừng
      tạo loại modifier thứ hai.
- [ ] **`levels_achievability_test.dart` vẫn xanh** cho toàn bộ 260 màn với
      luật mới bật. Đây là AC quan trọng nhất — nếu luật nào làm màn bất khả
      thi, sửa luật, không nới test.
- [ ] Người chơi thấy được luật đang áp dụng: 1 dòng ở màn chọn level hoặc
      HUD, đã i18n. Luật vô hình = luật không tồn tại.
- [ ] Luật thời tiết **không** áp dụng cho side-mode (side-mode dùng
      `PopLevel` tổng hợp không thuộc world nào).
- [ ] Test: 1 case/luật trong `test/data/worlds_test.dart` + sweep
      achievability.

## Subtask
1. `worlds.dart` — thêm map `WeatherKind → modifier`.
2. `pop_star_game.dart` / `game_controller.dart` — nối vào chỗ modifier hiện
   có đọc (`activeGameplayModifier`). Nếu `GauntletModifier` biểu diễn được
   4/5 luật, làm 4 cái đó trước và **bỏ** cái thứ 5 thay vì mở rộng kiểu.
3. UI hiện luật.
4. Chạy `levels_achievability_test.dart`, tune tới khi xanh.
5. Test + i18n.

## Ghi chú kỹ thuật
Bắt đầu bằng **2 luật** (mưa = combo window dài hơn, tuyết = thêm ice) — cả
hai chỉ là gán giá trị vào cơ chế đã chạy, gần như không có code mới. Chơi
thử, đo, rồi mới quyết có làm 3 cái còn lại không. Làm cả 5 ngay từ đầu là
cách chắc chắn nhất để phá cân bằng 260 màn cùng lúc.

DoD chung: `../README.md`.

---

## Đã làm

**Bảng luật tập trung** ở `lib/data/worlds.dart` (`kWeatherRules`,
`weatherRuleForLevel`), tái dùng thẳng `GauntletModifier` — khuôn đã phục vụ
Gauntlet/Treasure Map/Remix — thay vì dựng loại modifier thứ hai. Chỉ thêm đúng
1 field vào khuôn cũ (`bigGroupBonus` + `bigGroupThreshold`).

**Nối dây** qua đúng đường sẵn có: `activeGameplayModifier` thêm nhánh
`GameMode.campaign => activeWeatherModifier`, chụp ở `startLevel`. Nhờ vậy
`comboWindowOverride` tự chạy — engine không cần một dòng nào mới.

| Thời tiết | World | Luật |
|---|---|---|
| `bubble` | 41-60, 161-180 | cửa sổ combo 3.0 → 3.5s |
| `spark` | 21-40, 141-160 | nhóm ≥7 ô được ×1.2 điểm |
| `snow` | 121-140 | **chưa có** — xem dưới |
| `none` | 8 world còn lại | không luật |

**UI:** dòng luật ngay dưới tên vùng trên banner `LevelSelectScreen`, i18n
(en + vi), world không có luật thì không dựng gì.

## Vì sao snow bị hoãn

AC yêu cầu `levels_achievability_test.dart` xanh. Nó **xanh** — nhưng đọc kỹ thì
nó mô phỏng bàn **màu thuần**, không obstacle không ice. Nghĩa là nó **không thể
bắt** hồi quy của luật "tăng mật độ ice". Chạy nó rồi tuyên bố an toàn là tự lừa
mình.

Nên hai luật đã ship đều thuộc loại **chỉ cộng thêm** (combo window dài hơn,
điểm thưởng nhóm lớn): đúng theo cấu trúc là không thể làm màn khó hơn, nên
achievability giữ nguyên mà không cần mô phỏng lại. `snow` (tăng ice) là luật
trừ đi đầu tiên và phải chờ mở rộng bộ mô phỏng để mô hình hoá ice trước.

Đúng như ghi chú kỹ thuật của chính task này: làm cả 5 luật ngay là cách chắc
chắn nhất để phá cân bằng 260 màn cùng lúc.

## Lỗi bắt được khi build lên máy

Bản đầu thả dòng luật thẳng vào `Stack` của banner — `Stack` ở đó là để lớp
hoạ tiết chạy **nền sau** chữ, nên dòng luật vẽ **đè lên** tên world. Trên
Samsung S24 Ultra đọc ra `World rCietrluss GTrove`. Sửa: bọc tên + luật trong
`Column` riêng. Screenshot không giữ được bất biến này nên đã khoá bằng test so
toạ độ.

## Kiểm chứng

- `test/data/weather_rules_test.dart` — **21 ca**. Nhóm "an toàn: chỉ luật cộng
  thêm" là nhóm quan trọng nhất: không luật nào được rút ngắn combo window,
  giới hạn lượt, ép nhóm tối thiểu, khoá undo, hay đặt hệ số điểm < 1. Ai thêm
  luật trừ đi sẽ đỏ **trước khi** kịp phá cân bằng.
- `test/widget/world_rule_banner_test.dart` — 4 ca, trong đó ca so toạ độ khoá
  đúng lỗi đè chữ ở trên.
- `levels_achievability_test.dart` — 260/260 xanh.
- **Mutation-check 5/5 bị bắt:** luật rút ngắn combo window; campaign không đọc
  luật; bỏ ngưỡng nhóm lớn; trả `Column` về `Stack` children; (M2 bỏ chốt
  `id <= 0` **không** bị bắt — xem dưới).
- Verify trên thiết bị thật: world 1 (`none`) không có dòng luật, banner sạch.

## Nợ đã ghi, không giấu

1. **Chốt `id <= 0` trong `weatherRuleForLevel` hiện chưa chứng minh được.**
   Gỡ nó mà test vẫn xanh — không phải vì thừa, mà vì world cuối đang là
   `WeatherKind.none` nên `orElse: kWorlds.last` vô tình trả null. Đã đặt
   TRIPWIRE trong test: ai gán thời tiết có luật cho world cuối sẽ thấy đỏ đúng
   lúc chốt đó bắt đầu có tác dụng thật.
2. **snow chưa có luật** — có ca test riêng ghi rõ là *cố ý*, ai thêm luật cho
   snow buộc phải xoá ca đó và khi ấy phải đọc lý do.
3. i18n mới chỉ en + vi (đúng DoD tối thiểu); 20 ngôn ngữ còn lại rơi về bản en
   qua `_extraEn`.
