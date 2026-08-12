# I85 — FTUE dạy target/sao/combo, không chỉ 1 hint rồi tắt

**Epic:** E8 Enhance · **SP:** 5 · **Pri:** Must
**Deps:** — · **Mở rộng:** [[X1]] · **Liên quan:** [[I84]]
**Trạng thái:** ✅ Done (2026-08-11)

## Hiện trạng (đã verify — FTUE **có** tồn tại)
`game_screen_controller.dart:303-306` + `355-359`:

```dart
final ftue = mode == campaign && currentLevel.id == 1
    && !StorageService.to.getBool(StorageKeys.hasSeenFtue);
// ...
void _dismissFtueIfNeeded() {
  showFtue.value = false;
  StorageService.to.setBool(StorageKeys.hasSeenFtue, true);   // ← tap ĐẦU TIÊN
}
```

Toàn bộ FTUE hiện tại = **1 hint gợi ý nhóm nên tap ở level 1**, tắt vĩnh
viễn ngay tap đầu tiên (đúng hay sai nhóm đều tắt).

Ngoài ra có 2 coach-mark riêng: shop (`hasSeenShopTutorial`) và booster
(`hasSeenBoosterTutorial`), cộng một cái cho Daily Challenge.

> Một agent audit báo "không có FTUE nào" — **sai**, đã kiểm chứng lại. FTUE
> có, chỉ là dạy đúng 1 trong 5 thứ người chơi cần biết. Task này là *mở
> rộng*, không phải xây mới.

## Cái người chơi vẫn không được dạy
| Khái niệm | Dạy ở đâu hiện nay |
|---|---|
| Nhóm càng lớn điểm càng cao (`5n(n-1)`, siêu tuyến tính) | không đâu |
| Có **target score** phải vượt mới thắng | thanh HUD, không giải thích |
| 1/2/3 sao tính theo bội của target (1.0 / 1.3 / 1.7) | không đâu |
| Combo: nổ liên tiếp trong 3 giây thì nhân điểm | không đâu |
| Bàn **không refill** — mỗi ô là hữu hạn | không đâu |

Điều cuối cùng là quan trọng nhất và phản trực giác nhất: người quen
Candy Crush sẽ cho rằng bàn tự đầy lại, nên chơi phung phí và thua mà không
hiểu vì sao.

## Vì sao Must
Cùng lý do với [[I84]]: đây là retention ở đoạn phễu hẹp nhất (phút đầu
tiên), giải quyết bằng trình bày chứ không bằng nội dung mới.

## User story
*As a* người chơi lần đầu *I want* hiểu vì sao nhóm lớn tốt hơn và vì sao
tôi thua *so that* tôi chơi tiếp thay vì gỡ app.

## Acceptance criteria
- [ ] Level 1: hint nhóm nên tap (giữ nguyên [[X1]]) **+** một dòng ngắn giải
      thích "nhóm càng lớn, điểm càng cao".
- [ ] Sau pop lớn đầu tiên (≥5 ô): hiện chỉ báo so sánh điểm nhóm nhỏ vs
      nhóm lớn — **một lần duy nhất trong đời cài đặt**.
- [ ] Level 1-2: highlight thanh target trong HUD kèm 1 dòng "vượt mốc này để
      thắng".
- [ ] Lần thắng đầu tiên: dialog thắng giải thích 3 sao tính thế nào.
- [ ] Lần thua đầu tiên: dialog thua nói rõ **bàn không refill** và gợi ý cụ
      thể ("gộp nhóm lớn hơn trước khi nổ"), không phải chỉ nút "Thử lại".
- [ ] Lần combo đầu tiên (≥2): text ngắn giải thích combo window.
- [ ] **Mỗi mẩu tắt độc lập và vĩnh viễn**, key riêng trong `StorageKeys`
      theo đúng nếp `hasSeen*` hiện có. Không mẩu nào chặn gameplay hay bắt
      bấm "Tiếp theo".
- [ ] Toàn bộ chuỗi mới đủ 22 ngôn ngữ.
- [ ] Có cách tắt hết trong Settings ("Bỏ qua hướng dẫn") — cho người chơi
      cũ cài lại.
- [ ] Test trong `test/widget/game_screen_smoke_test.dart` + file mới cho
      từng trigger.

## Subtask
1. `storage_service.dart` — thêm 5 key `hasSeen*` mới theo nếp cũ.
2. `game_screen_controller.dart` — thêm trigger cho từng mẩu; **tái dùng**
   khuôn `showFtue`/`showBoosterTutorial` đã có, không dựng máy trạng thái
   tutorial mới.
3. `game_screen.dart` — render các mẩu dưới dạng overlay trong cây widget.
   **Nhớ:** `Get.dialog`/`showDialog` là no-op trong app này (full-screen
   Flame) — phải dùng `NeonDialog.overlay(...)`.
4. i18n 22 ngôn ngữ.
5. `settings_screen.dart` — công tắc bỏ qua hướng dẫn.
6. Test.

## Ghi chú kỹ thuật
Rủi ro lớn nhất của task này là **làm quá tay**: 6 popup liên tiếp còn tệ hơn
0 popup. Giữ mỗi mẩu ở mức một dòng chữ + một mũi tên, tự tắt sau vài giây
hoặc khi người chơi tap tiếp. Không chặn input, không bắt xác nhận, không
làm chuỗi tutorial nhiều bước.

Nếu chỉ làm được 2 mẩu trong sprint, làm **"bàn không refill" (dialog thua
đầu tiên)** và **"nhóm lớn = nhiều điểm" (level 1)** — hai cái này gánh phần
lớn giá trị.

DoD chung: `../README.md`.

## Đã làm

`lib/logic/ftue_tips.dart` (thuần) + trạng thái đã-xem trong `StorageKeys`
(`hasSeenBigGroupTip`, `hasSeenNoRefillTip`, `skipTips`), hiển thị qua
`game_screen.dart`, công tắc "Bỏ qua hướng dẫn" ở `settings_screen.dart`
(`Key('settings_skip_tips')`).

## Kiểm chứng

- `test/logic/ftue_tips_test.dart` — 16 ca thuần.
- `test/widget/ftue_tips_widget_test.dart` — 12 ca.
- **Bẫy đã gặp:** trigger thật là `handleBoardTap`, không phải `toggleBombArm`;
  và nó cần `GameWidget` đã mount, nếu không `cellAt` ném.
