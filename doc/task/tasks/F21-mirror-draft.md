# F21 — Mirror Draft: tap của bạn nổ đối xứng ở nửa bàn đối thủ

**Epic:** E9 Tính năng mới · **SP:** 8 · **Pri:** Could
**Deps:** [[T2]] (`pass_and_play_controller` chưa có test)
**Tái dùng:** [[I47]] mirror board · [[I59]] pass & play
**Trạng thái:** ✅ Done (2026-08-13)

## Pitch
Hai người chơi trên một bàn đối xứng gương. Mỗi người chỉ điều khiển nửa của
mình — nhưng mỗi cú tap **cũng nổ nhóm đối xứng ở nửa bên kia**. Điểm chung,
kết quả chung.

## Vì sao độc quyền
Cơ chế "hành động của tôi giúp *và* cản bạn cùng lúc" không tồn tại trong
thể loại này. Nó tạo ra một loại đàm phán giữa hai người ngồi cạnh nhau
("đừng nổ chỗ đó, tôi đang gom!") mà cả co-op thuần lẫn cạnh tranh thuần đều
không có.

Hạ tầng: `mirror_board.dart` đã sinh bàn đối xứng cho Mirror Mode (I47);
`pass_and_play.dart` đã có logic lượt hot-seat.

## Vì sao Could
Cơ chế **khó hiểu** — đó là rủi ro chính, không phải độ khó kỹ thuật. Người
chơi phải nắm được rằng nước đi của mình có hai hệ quả ở hai nơi, và điều đó
cần onboarding riêng cho một mode Could.

## User story
*As a* hai người chơi *I want* nước đi của tôi ảnh hưởng cả hai nửa bàn
*so that* chúng tôi phải phối hợp thay vì chơi song song.

## Acceptance criteria
- [ ] Bàn đối xứng gương sinh bằng `generateMirrorBoard` (đã có), không viết
      generator mới.
- [ ] Tap ở nửa A cũng nổ nhóm tại vị trí gương ở nửa B — **nếu** nhóm đó hợp
      lệ ở B. Nhóm không hợp lệ ở B → chỉ nổ ở A. **Chốt rõ hành vi này và
      test nó**; đây là quy tắc dễ gây tranh cãi nhất.
- [ ] Điểm chung, hiển thị chung, kết quả chung.
- [ ] Bàn phân kỳ sau vài nước (vì luật trên) — UI phải làm rõ nửa nào là của
      ai. Đối xứng vỡ dần là **đặc điểm**, không phải lỗi.
- [ ] Hướng dẫn riêng lần đầu vào mode, tối đa 2 câu, tắt vĩnh viễn sau đó
      (nếp `hasSeen*`).
- [ ] Best score riêng, key riêng; không đụng progress campaign.
- [ ] i18n 22 ngôn ngữ; test cho luật nổ-gương (cả 2 nhánh), phân định kết quả.

## Subtask
1. **Prototype luật gương trước tiên** — thuần logic, không UI. Nếu chơi thử
   trên giấy/test mà thấy khó hiểu, dừng lại và đóng task. Đây là bước rẻ
   nhất để bác bỏ ý tưởng.
2. `lib/logic/mirror_draft.dart` — hàm thuần: cho một tap ở nửa A, trả về
   tập ô cần nổ ở cả hai nửa.
3. Nối vào `pop_star_game.dart` như một luật của mode.
4. Controller run (khuôn `pass_and_play_controller`).
5. UI + hướng dẫn + i18n + test.

## Rủi ro
- **Luật khó hiểu** → mode bị bỏ. Giảm bằng subtask 1 (prototype logic trước
  khi đầu tư UI) và hướng dẫn 2 câu.
- **Đối xứng vỡ trông như bug.** Cần tín hiệu hình ảnh rõ khi nước đi *không*
  nổ được ở nửa bên kia — nếu không, người chơi sẽ báo lỗi.
- Trùng lặp với [[F20]]: cả hai là co-op 2 người trên một máy. **Chỉ làm một
  trong hai.** F21 rẻ hơn và độc đáo hơn; F20 dễ hiểu hơn.

DoD chung: `../README.md`.

---

## Subtask 1: prototype luật trước, kết quả

Chơi thử 6 nước bằng test thuần trên bàn gương 6×6 trước khi đụng UI. Đọc được:
có nước nổ cả hai nửa, có nước chỉ nổ một bên, bàn phân kỳ dần. Luật đứng
vững nên làm tiếp — nếu khó hiểu thì đã đóng task ở đây như subtask 1 yêu cầu.

## Luật đã chốt

Nhóm gương **chỉ** nổ khi nó cũng hợp lệ ở nửa bên kia. Ba ca ngoại lệ, đều có
test:

| Ca | Xử lý | Vì sao |
|---|---|---|
| Nửa kia đã phân kỳ, không còn nhóm | chỉ nổ bên tap | ép nổ = xoá ô không cùng màu, vô lý |
| Tap cột giữa (bàn lẻ) | chỉ nổ một lần | cột giữa tự soi vào chính nó |
| Nhóm chạy **ngang** qua trục | chỉ nổ một lần | hai bên là MỘT nhóm, nhân đôi là cộng điểm khống |

`lastMirrorMirrored` cho UI biết nước vừa rồi có nổ được nửa kia không — thiếu
tín hiệu này thì "đối xứng vỡ" trông như bug, đúng rủi ro task ghi.

## Nối vào engine: MỞ RỘNG nhóm, không rẽ nhánh

`_tryPop` là đường hot dùng chung cho mọi mode. Thay vì thêm một lối đi song
song (thêm một chỗ để lệch), luật gương chỉ **mở rộng tập ô** rồi để nguyên
đường điểm/combo/power-tile chạy tiếp.

## Bug nghiêm trọng tìm được — ảnh hưởng cả [[F16]]

Test dựng engine thật cho thấy bàn Mirror Draft **không đối xứng**. Nguyên
nhân: `presetGrid` chọn theo mode trong `GameScreenController`, và mode mới
không có trong danh sách → rơi vào `_ => null` → engine **tự sinh bàn ngẫu
nhiên**.

Nghĩa là **F16 Ghost Duel cũng hỏng**: hai người chơi hai bàn khác nhau — phá
đúng tiền đề của tính năng. Test controller của F16 không bắt được vì nó chỉ
kiểm `puzzleLabGrid`; chỉ test dựng engine mới thấy.

Đã tách phép chọn thành hàm thuần `presetGridForMode(gameCtrl)` và test trực
tiếp, để mode thêm sau này quên đăng ký thì đỏ ngay thay vì im lặng.

## Kiểm chứng

- `test/logic/mirror_draft_test.dart` — 13 ca (cả 3 ngoại lệ, toạ độ ngoài
  bàn, không sửa bàn gốc, nối với `generateMirrorBoard` thật).
- `test/presentation/mirror_draft_wiring_test.dart` — 8 ca, gồm ca chốt
  **không đè best của Mirror Mode (I47)** — hai mode tên gần giống nhau.
- `test/game/mirror_draft_engine_test.dart` — 6 ca dựng engine thật + 3 ca cho
  `presetGridForMode`.
- **Mutation-check 5/5 bị bắt** sau khi bổ sung test engine (ban đầu 3/5).
- Verify Pixel 7 Pro: "Gương Đôi" trong nhóm Xã hội → bàn đối xứng → tap nhóm
  2 ô nửa trái làm **4 ô** biến mất, điểm 60 = `scoreForGroup(4)`.
- `RELEASE_CHECKLIST.md`: 15 → 16 side mode.
- Toàn bộ suite: **1513 xanh**.

## Hai ca test tự sửa vì assertion sai, không phải sản phẩm sai

1. "mode khác không bị áp luật gương" đỏ với 7/8 ô — vì campaign **giữ lại 1 ô
   làm power tile** khi nhóm ≥5. Đổi sang chỉ chọn nhóm 2..4.
2. "nổ gấp đôi" đỏ 2/3 lần vì cùng lý do. Đổi assertion sang "nổ nhiều hơn
   nhóm vừa tap" + biên `total-1..total`.

## Trả nợ UI (cùng ngày)

Hai khoản nợ lớn nhất đã trả:

1. **Hướng dẫn 2 câu lần đầu** — dùng CHUNG bong bóng FTUE của I85, không dựng
   overlay tip thứ ba. Tôn trọng cả `hasSeenMirrorDraftTip` lẫn công tắc "bỏ
   qua hướng dẫn" (`skipTips`), và tắt ngay ở tap đầu tiên.
2. **Tín hiệu khi nửa kia KHÔNG nổ** — `mirrorMissTick` tăng mỗi nước chỉ nổ
   một bên; UI hiện nhãn thoáng qua 900ms. Đây là rủi ro số 2 của task
   ("đối xứng vỡ trông như bug"), giờ có lời giải thích tại chỗ.

Kiểm chứng: `test/widget/mirror_draft_ui_test.dart` — 8 ca (hiện/không hiện
theo `hasSeen*` và `skipTips`, tắt là nhớ vĩnh viễn, mode khác không hiện,
độ dài hướng dẫn < 160 ký tự, tick tăng đúng khi nổ một bên).
**Mutation-check 3/3 bị bắt.**

Verify Pixel 7 Pro: hướng dẫn hiện đúng 2 câu tiếng Việt giữa bàn. **Nhãn
"nửa bên kia không có nhóm khớp" KHÔNG bắt được bằng ảnh chụp** — nó chỉ sống
900ms, ngắn hơn thời gian `screencap` + `uiautomator dump`. Phần này mới chỉ
có test chứng minh, chưa nhìn tận mắt.

## Nợ còn lại
1. Mode dùng chung điểm/lượt, chưa phân định "nửa nào của ai" trên UI.
2. i18n mới en + vi.
