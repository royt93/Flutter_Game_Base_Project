---
id: w27-1-device-verify-1abc
title: Device-verify — Boss telegraph (1A) + ColorRush refill-bias (1B) + Thử Thách (1C)
wave: 27
phase: 1
status: todo
owner: claude
created: 2026-07-04
---

> 🟢 **2026-07-05** — 1B đã verify xong bằng mắt trên Pixel 7 Pro (`2B051FDH3006MU`): chơi ColorRush
> 13 lượt swap, đo mật độ màu nóng 4 lần (21.9%–23.4%, trên baseline ~16.7%), quan sát 2 lần đổi màu
> nóng (bias bám đúng màu mới), không giật/lag.
>
> 🟢 **2026-07-05** — 1C đã verify xong trên R5CX613VZBR: icon 🔥 xuất hiện đúng sau Gold, lượt giảm
> ~15% (30→26) khi bật, thưởng tăng ~51% (+45→+68 xu) khi thắng ván bật, tắt icon trả về bình thường
> (LƯỢT: 30, chơi thật), campaign không bị leak (không icon, "LƯỢT: 26" ở campaign level 1 là trùng
> lặp giá trị cố định của chính level đó, không phải hard-variant). **Phase 1 (1A/1B/1C) hoàn tất** —
> chỉ còn mục tuỳ chọn ở 1A (verify thêm 1 stage chẵn, không bắt buộc).

# Phase 1 — Device-verify Wave 25.1 (1A/1B/1C)

Theo [[w25-1-mode-depth]]: 1A đã unit-test + device-verify xong; 1B/1C có unit-test xanh (969 passed)
nhưng **chưa nhìn bằng mắt trên device**. Task này verify cả 3 (đủ tài liệu), tập trung 1B/1C.
Theo R3: `adb devices` + chọn target trước; theo R4: dừng nếu gặp ad che UI (app không có ad SDK → ok).

## 1A — Boss telegraph → meteor (đã verify — chỉ xác nhận lại nếu cần)
- [x] Vào Boss mode, đợi phase đổi (HP thấp) → thấy vòng tròn tím cảnh báo (telegraph) ở vùng sắp bị
  meteor đánh trước 1 lượt. **Đã verify 2026-07-04 trên R5CX613VZBR ("Xung Kích · TRÙM NEON 1").**
- [x] ❌ **Skipped 2026-07-05** — Đã thử verify stage chẵn (voidType) trên R5CX613VZBR (unlock tạm
  level 21 để vào "Hắc Ám · TRÙM NEON 2"), đạt tới internal phase 2 (UI "PHASE 3") ổn định. Trong lúc
  tìm dấu hiệu telegraph, đọc nhầm 1 viền tròn xám/bạc (không liên quan) quanh 2 ô gem là ứng viên,
  tốn nhiều thời gian mới phát hiện sai. Đọc lại code thật (`neon_jewel_game.dart:2932-2962`, class
  `_MeteorWarning`) xác nhận telegraph thật là **ô vuông đỏ nhấp nháy** (`NeonTheme.red`, alpha dao
  động theo sin) — câu chữ "vòng tròn tím" trong checklist ở trên là diễn giải không khớp code, không
  phải mô tả chính xác. Do mục này là **tuỳ chọn** (1A cốt lõi đã verify đủ ở pulse-type 2026-07-04) và
  đã tốn quá nhiều thời gian trong phiên, quyết định dừng, bỏ qua — không tiếp tục đuổi theo trên
  voidType. Đã revert `flutter.unlockedLevel` (xoá key, về default code = 1) trên R5CX613VZBR.

## 1B — ColorRush refill-bias (đã verify 2026-07-05 trên 2B051FDH3006MU)
- [x] Vào ColorRush, chơi vài ván (≥10 lượt), quan sát màu "nóng" (hiển thị trên HUD/chip streak) có
  rơi/refill **nhiều hơn rõ rệt bằng mắt** so với 5 màu khác không. **Đã verify: 13 swap, 4 điểm đo mật
  độ màu nóng (green) 21.9%–23.4%, đều rõ trên baseline không-bias ~16.7%.**
- [x] Đổi màu nóng (mỗi `kColorRushChangeEvery` lượt) → xác nhận màu mới cũng được ưu ái refill (bias
  bám theo `colorRushHot`, không cứng 1 màu). **Đã verify: 2 lần đổi màu nóng trong phiên (cyan→magenta,
  magenta→green), mật độ đo lại đúng theo màu mới mỗi lần.**
- [x] Không thấy giật/lag khác thường khi refill (bias chỉ đổi màu chọn, không đổi tốc độ animation).
  **Đã verify: không giật/lag ở bất kỳ swap nào trong toàn phiên.**

## 1C — "Thử Thách" (hard variant, sau Gold)
- [x] Đạt Gold ở 1 mode phụ (ví dụ ColorRush) → icon toggle 🔥 xuất hiện cạnh badge kỷ lục trên Home
  (trước đó chưa Gold thì KHÔNG thấy icon này). **Đã verify 2026-07-05 trên `2B051FDH3006MU`**: dùng
  `adb shell "run-as ... " ` set `rec_colorRush_v=15, rec_colorRush_t=3` (Gold, chỉ để mở khoá UI test —
  KHÔNG phải chơi thật, đã revert về `v=1, t=1` sau khi xong 1C) → icon 🔥 xuất hiện đúng vị trí cạnh
  badge Gold trên Home; trước đó (tier thấp hơn) icon này không xuất hiện.
- [x] Bật icon 🔥 → vào ván mode đó, xác nhận `movesLeft` ban đầu **ít hơn ~15%** so với bình thường.
  **Đã verify**: HUD hiển thị "LƯỢT: 26" khi bật 🔥 (khớp `(30 * 0.85).ceil() = 26`), so với "LƯỢT: 30"
  khi tắt 🔥 (chơi thật, không inject).
- [x] Thắng ván (bật Thử Thách) → xác nhận xu thưởng **nhiều hơn ~50%** so với ván tắt Thử Thách
  (cùng điểm số/base tương đương). **Đã verify trên R5CX613VZBR**: chơi thật 2 ván ColorRush cùng mức
  điểm — tắt 🔥 được +45 xu, bật 🔥 được +68 xu (~51% tăng, khớp `kHardVariantRewardMul = 1.5`).
- [x] Tắt icon 🔥 → ván tiếp theo trở lại lượt/thưởng bình thường (không dính trạng thái cũ).
  **Đã verify trên R5CX613VZBR**: nhận diện đúng trạng thái icon bằng cách crop ảnh chụp màn hình vào
  đúng vùng icon (viền mờ = OFF, đầy màu sáng = ON — khác biệt khó thấy nếu nhìn cả màn hình), tap về
  đúng trạng thái OFF, vào ván ColorRush mới (chơi thật) → HUD hiển thị "LƯỢT: 30" (bình thường), không
  còn dính "LƯỢT: 26" của lần bật trước.
- [x] Vào campaign (level thường) → xác nhận UI không có icon 🔥, lượt/thưởng không bị ảnh hưởng dù
  đã bật Thử Thách ở mode phụ khác (test unit đã xác nhận, verify lại bằng mắt cho chắc). **Đã verify**:
  quan sát UI campaign level 1 — không có icon 🔥 ở đâu (pregame, HUD trong ván). "LƯỢT: 26" từng thấy ở
  campaign level 1 chỉ là trùng lặp — đây là giá trị lượt cố định của chính level 1 trong `levels.dart`,
  không liên quan hard-variant. Trace code xác nhận: `activeKind` (side_mode_record_controller.dart:115)
  luôn `null` khi chơi campaign, và `discountSideModeReward` chỉ được gọi từ các nhánh side-mode riêng,
  không bao giờ từ campaign → hard-variant không thể leak sang campaign dù đang bật ở mode phụ khác.

## Lưu ý
- 🚫 KHÔNG commit (user tự commit) — xem [[code-on-main-only]].
- Nếu phát hiện ad che UI → dừng ngay theo R4, báo user (loại ad, vị trí), chờ "done".
- Nếu lệch visual (bias không rõ rệt, icon 🔥 sai vị trí...) → tinh chỉnh tham số ngay trong phiên có
  device, không để lại nợ.
- Link: [[w25-1-mode-depth]] (nguồn code+test gốc của cả 1A/1B/1C).
