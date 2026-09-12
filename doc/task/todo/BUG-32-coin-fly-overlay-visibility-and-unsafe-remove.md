---
id: BUG-32
title: "CoinFlyOverlay: coin hiện sẵn ở điểm đầu/cuối ngoài khung animation, và entry.remove không kiểm tra mounted"
type: bug
priority: P3
effort: S
source: Gemini (agy CLI, audit widget enhancement — tái phân loại thành bug)
---

## Vị trí
`lib/presentation/widgets/common/coin_fly_overlay.dart`.

## Hiện trạng
2 vấn đề: (1) Mỗi coin `i` được vẽ tại `from` TRƯỚC khi tới lượt bay (`_controller.value < _startAt[i]`) và tại `to` SAU KHI đã tới đích (`_controller.value >= _endAt[i]`) — nghĩa là toàn bộ coin CHƯA bay đứng chồng lên nhau ở điểm xuất phát, và toàn bộ coin ĐÃ bay đứng chồng ở đích cho tới khi cả overlay kết thúc, thay vì chỉ hiện đúng trong lúc đang bay. (2) `CoinFlyOverlay.show` truyền `onDone: entry.remove` như 1 tear-off trực tiếp, không kiểm tra `entry.mounted` — nếu overlay đã bị dismiss hoặc widget tree unmount trong lúc animation đang chạy (ví dụ người chơi điều hướng đi màn hình khác), gọi `entry.remove` throw `FlutterError`. `FloatingComboText.show` (widget chị em) đã xử lý đúng bằng `if (entry.mounted) entry.remove()`.

## Vì sao cần / Hậu quả
Coin "đóng cục" ở điểm đầu/cuối làm hiệu ứng bay tiền trông rối/kém xịn (đặc biệt với `coinCount` lớn) — mâu thuẫn trực tiếp với IDEA-22 (quỹ đạo cong + squash) vừa làm trong session trước, vì hiệu ứng đẹp đó chỉ thấy được TRONG khung animation, còn bị che bởi coin đứng yên chồng lên nhau ở 2 đầu. Crash risk (2) là bug thật, có thể crash khi điều hướng nhanh trong lúc coin đang bay.

## Đề xuất
Chỉ render (hoặc set opacity 0) coin `i` khi `_controller.value` nằm trong `[_startAt[i], _endAt[i])` — ẩn hẳn trước khi tới lượt và sau khi đã đến đích. Đổi `onDone: entry.remove` thành `onDone: () { if (entry.mounted) entry.remove(); }`, đúng pattern đã có ở `FloatingComboText.show`.

## Acceptance criteria
- [ ] Coin chưa tới lượt bay hoặc đã tới đích không còn hiển thị chồng lên nhau ở 2 đầu quỹ đạo.
- [ ] entry.remove chỉ gọi khi entry.mounted, không crash khi overlay bị unmount giữa lúc animation đang chạy.
- [ ] Test widget: xác nhận số coin visible tại 1 thời điểm giữa animation khớp đúng với số coin đang trong khung [startAt, endAt) của chúng; test unmount CoinFlyOverlay giữa chừng animation không throw.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-32-coin-fly-overlay-visibility-and-unsafe-remove.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — vấn đề (1) là bug thị giác thật (không phải chỉ thẩm mỹ chủ quan — hành vi sai với ý đồ thiết kế rõ ràng của animation timeline), vấn đề (2) là crash risk thật theo đúng pattern đã biết và đã fix ở widget chị em.
