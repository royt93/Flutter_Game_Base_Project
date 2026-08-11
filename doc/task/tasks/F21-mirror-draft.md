# F21 — Mirror Draft: tap của bạn nổ đối xứng ở nửa bàn đối thủ

**Epic:** E9 Tính năng mới · **SP:** 8 · **Pri:** Could
**Deps:** [[T2]] (`pass_and_play_controller` chưa có test)
**Tái dùng:** [[I47]] mirror board · [[I59]] pass & play
**Trạng thái:** 📋 To Do

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
