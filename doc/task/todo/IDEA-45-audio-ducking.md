---
id: IDEA-45
title: "AudioManager: audio ducking cho BGM khi SFX quan trọng phát"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: M
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua agent quét codebase độc lập)
---

## Vị trí
Mở rộng `lib/core/audio_manager.dart`.

## Hiện trạng
`AudioManager` phát 1 track BGM cố định volume + `playSfx` cho SFX rời rạc từ asset app. Không có cơ chế "ducking" (tạm giảm volume BGM khi 1 SFX quan trọng phát rồi trả lại) — pattern âm thanh chuẩn trong game casual (ví dụ: tiếng thắng/thua, tiếng combo lớn cần nổi bật hơn nhạc nền).

## Vì sao cần / Hậu quả
Thiếu ducking khiến SFX quan trọng bị nhạc nền lấn át về cảm nhận âm lượng, đặc biệt trên loa điện thoại nhỏ — game dùng kit phải tự implement lại toàn bộ fade-volume-rồi-fade-back bằng tay nếu muốn có hiệu ứng này.

## Đề xuất
Thêm tham số optional (ví dụ `duck: true` hoặc factor riêng) cho `playSfx` — khi bật, `AudioManager` tự giảm volume BGM (`Bgm`) xuống 1 mức trong lúc SFX phát, rồi trả về volume gốc ngay sau khi SFX kết thúc (hoặc sau timeout an toàn nếu không biết chính xác thời lượng SFX). Giữ đơn giản — KHÔNG cần fade mượt qua nhiều frame nếu 1 bước giảm/tăng volume tức thời đã đủ tự nhiên (tránh over-engineer); nếu cảm nhận thực tế cần fade mượt thì mới thêm animation volume, không mặc định làm phức tạp trước khi nghe thử.

## Acceptance criteria
- [ ] BGM tự giảm volume khi 1 SFX (được đánh dấu duck) phát, tự trả về volume gốc sau khi xong.
- [ ] Nhiều SFX duck chồng lên nhau không làm BGM bị kẹt ở volume thấp vĩnh viễn (phải trả về đúng volume gốc sau SFX cuối cùng kết thúc).
- [ ] SFX không đánh dấu duck không ảnh hưởng BGM volume, hành vi cũ giữ nguyên (không phá test/API hiện có).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case: duck chồng lặp, muted trong lúc duck, dispose trong lúc đang duck) — unit/widget/integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) — bằng chứng cụ thể trong Quyết định (nghe thử thật, không chỉ đọc log).
- [ ] Không có widget UI mới trực tiếp — N/A cho yêu cầu animation nếu không đụng UI.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-45-audio-ducking.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc.
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò — không áp dụng ở đây (không có widget mới), nhưng nếu volume transition được implement dạng fade thì fade đó cũng phải mượt, không giật cục.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — nghe thử thật, log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — pattern audio ducking chuẩn, có giá trị thật, nhưng dễ over-engineer nếu cố làm fade mượt qua nhiều frame ngay từ đầu thay vì bắt đầu từ bước giảm/tăng đơn giản nhất; cũng cần nghe thử thật trên máy để đánh giá "đủ tự nhiên chưa" — nên thử bản đơn giản nhất trước, chỉ phức tạp hoá nếu nghe thử thấy chưa ổn.
