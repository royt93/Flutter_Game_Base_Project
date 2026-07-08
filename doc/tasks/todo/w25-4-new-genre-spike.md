---
id: w25-4-new-genre-spike
title: Spike thể loại mới (optional) — bề rộng ngoài match-3
wave: 25
phase: 4
status: todo
owner: claude
created: 2026-07-02
---

# Phase 4 — Spike 1 mode KHÁC THỂ LOẠI (thử nghiệm, có thể bỏ)

Hướng user (2): "cần mode khác biệt cơ bản, không chỉ biến thể match-3". Giữ lại vì user xác nhận,
nhưng đây là hướng **rủi ro loãng nhất + tốn nhất**. Làm dưới dạng **spike throwaway**: nếu chơi thử
không "đã" trong ~1 phiên → **bỏ, không ship**. KHÔNG cam kết trước.

> ⚠️ **Đọc trước khi làm**: 12+ mode hiện tại vẫn thấy sơ sài. Nếu Phase 1-3 đã cải thiện cảm giác,
> **cân nhắc SKIP phase này** — thêm thể loại mới trên một game match-3 dễ thành "mini-game lạc lõng"
> hơn là chiều sâu. Chỉ làm nếu thực sự muốn mở rộng scope sản phẩm.

## Ứng viên spike (chọn TỐI ĐA 1)
- [x] **Puzzle input khác**: kiểu "nối đường" / "xoay nhóm" trên chính gem grid — khác thao tác swap,
  tái dùng render gem sẵn có (chi phí thấp nhất trong nhóm này). → chọn **"xoay nhóm 2x2"**.
- [ ] **Mode tài nguyên / build nhẹ**: dùng xu-trong-ván để "xây" giữa các lượt (meta-trong-match).
- [ ] **Rơi khỏi genre**: mini-game phản xạ/né — cảnh báo: gần như viết engine mới, ROI thấp.

## Cách làm (spike kỷ luật)
- [x] Timebox rõ (vd 1 phiên). Prototype **sau 1 cờ debug**, KHÔNG vào Home/flow chính khi chưa "đã".
- [x] Tự chơi 10-15 phút → quyết định **go / no-go** thẳng thắn (ghi lý do vào file này).
- [ ] Nếu go: mới bóc thành task ship riêng (i18n, balance, isolation, test) ở wave sau.
- [x] Nếu no-go: xoá prototype, ghi "đã thử, bỏ vì …" — vẫn là kết quả hợp lệ.

## Kết luận: NO-GO (2026-07-07)

Đã thử **"xoay nhóm 2x2"**: chạm 1 ô → khối 2x2 (ô chạm là góc trên-trái) xoay 90° thuận chiều kim
đồng hồ; có match mới thì tiêu lượt + chạy pipeline resolve/settle/cascade sẵn có; không match thì
tự xoay ngược lại (không tốn lượt). Cài sau `kDebugMode`, entry point riêng ở Home (chỉ debug build).

**Kỹ thuật**: ổn định — tái dùng toàn bộ `MatchDetector`, `_settle()`/`_resolveAll()`,
`_ensurePlayable()`, `_swapLocked()` không cần sửa. Playtest ~25 lượt chạm trải khắp bàn (gồm góc/biên)
qua adb: xoay đúng chiều, revert đúng khi không match, không tốn lượt khi revert, cascade + tính điểm
vẫn đúng qua pipeline cũ, không crash/ANR trong logcat của tiến trình app.

**Bỏ vì**: cảm giác chơi không đủ hấp dẫn hơn swap để đáng chi phí ship. Thao tác "chạm 1 lần → tự
xoay 1 chiều cố định" không có bước ngắm/chọn hướng như swap (nơi thấy rõ 2 gem sẽ đổi chỗ và có thể
tính toán trước) — cảm giác giống "chọc thử chờ may" hơn là quyết định có chủ đích. Tỷ lệ match quan
sát được qua playtest ~20% (4/20 lượt chạm), gần với xác suất match ngẫu nhiên trên bàn dày đặc chứ
không phải nhờ insight chiến thuật rõ ràng của người chơi. Giá trị gameplay mới thêm vào so với
swap hiện có là thấp, không đáng đầu tư i18n/balance/isolation/test cho một mode ship riêng.
Prototype đã xoá khỏi 5 file lib + revert 1 file test (không commit, xem git diff nếu cần đối chiếu).

## Acceptance (của spike, không phải của mode ship)
- [x] Có kết luận go/no-go kèm lý do; nếu go, có task ship kế tiếp; nếu no-go, code đã dọn.
- [x] Không rò prototype vào build release (guard sau cờ debug); `flutter analyze` 0.

## Lưu ý
- Ưu tiên **thấp nhất** wave 25 — làm cuối, hoặc cắt nếu ngân sách hẹp.
- Nếu ship: phải theo [[side-mode-isolation]] + i18n + [[reset-permanent-controllers]] như mọi mode.
- 🚫 KHÔNG commit prototype ([[code-on-main-only]]).
