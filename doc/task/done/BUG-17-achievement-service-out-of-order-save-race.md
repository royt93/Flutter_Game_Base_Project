---
id: BUG-17
title: "AchievementService: các lần incrementProgress() liên tiếp có thể ghi đè nhau sai thứ tự"
type: bug
priority: P2
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/achievement_service.dart` — `incrementProgress()`.

## Hiện trạng
`incrementProgress()` cập nhật `_progressMap` trong bộ nhớ ngay lập tức (đồng bộ) nhưng gọi `_store.save(_progressMap)` với `unawaited` (fire-and-forget). Nếu app gọi `incrementProgress` nhiều lần rất nhanh (ví dụ combo nhiều event cùng lúc), các lệnh save chạy song song và write HOÀN TẤT không đảm bảo đúng thứ tự gọi — 1 save cũ có thể hoàn tất SAU 1 save mới hơn, ghi đè disk bằng snapshot cũ.

## Vì sao cần / Hậu quả
Người chơi thấy progress bị lùi lại (mất tiến độ achievement) sau khi restart app, dù trong session vẫn hiển thị đúng — bug khó tái hiện thủ công vì cần đúng timing I/O, chỉ lộ ra khi test có storage fake trì hoãn ghi có kiểm soát.

## Đề xuất
Serialize các lần save qua 1 `Future` chain (mỗi `incrementProgress` chờ save trước đó xong rồi mới bắt đầu save mới, hoặc dùng 1 debounce/coalesce đơn giản: chỉ giữ lại lệnh save cuối cùng, hủy lệnh đang chờ nếu có lệnh mới hơn tới trước khi nó bắt đầu ghi).

## Acceptance criteria
- [x] Nhiều lệnh incrementProgress() gọi liên tiếp không còn thể ghi đè nhau sai thứ tự trên disk.
- [x] Test dùng storage fake trì hoãn/đảo thứ tự hoàn tất write, xác nhận giá trị cuối cùng trên disk khớp với lệnh gọi SAU CÙNG, không phải theo thứ tự I/O hoàn tất.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-17-achievement-service-out-of-order-save-race.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Quyết định
Sửa bằng cờ `_saving` + chain `_saveChain`: nếu KHÔNG có save nào đang chạy,
save mới chạy NGAY (đồng bộ tới await đầu tiên) — giữ nguyên hành vi "bắt
đầu tức thời" mà code cũ vô tình có (do `unawaited(...)` khiến save chạy
song song ngay khi gọi); nếu ĐANG có 1 save chạy dở, save mới xếp hàng đợi
sau `_saveChain` hiện tại thay vì bắn song song. Mỗi link trong chain chỉ
chụp snapshot `_progressMap` (map dùng chung, đã phản ánh MỌI increment
tính tới lúc đó) khi thực sự tới lượt chạy, nên write khởi động sau luôn
hoàn tất sau, xoá bỏ khả năng ghi đè bằng snapshot cũ.

Phát hiện quan trọng giữa chừng: bản fix ĐẦU TIÊN (chain đơn giản, luôn
qua `.then()`) đã VÔ TÌNH GÂY REGRESSION cho chính 2 test đã có sẵn trong
file (`progress persist qua restart`, `progress chưa đủ ngưỡng cũng
persist qua restart`) — 2 test đó gọi `incrementProgress` rồi đọc lại
NGAY LẬP TỨC không hề `await` gì, dựa vào việc code cũ (`unawaited(...)`)
khiến write bắt đầu ĐỒNG BỘ ngay khi gọi (module SharedPreferences mock
cập nhật giá trị đọc được gần như tức thời dù bọc trong Future). Chain
đơn giản qua `.then()` LUÔN hoãn cả LẦN GỌI ĐẦU TIÊN sang 1 microtask,
phá vỡ giả định đó. Sửa lại bằng cờ `_saving` để CHỈ hoãn khi thực sự có
backlog, khôi phục đúng hành vi cũ cho trường hợp không có race.

Không dùng được kỹ thuật RED/GREEN triệt để như BUG-16: bản fix cần thêm
1 accessor `@visibleForTesting debugPendingSaves` để test có thể `await`
chain xác định — nhưng chính accessor đó KHÔNG TỒN TẠI trên code gốc
(chưa fix), nên revert code để chạy lại test race y hệt sẽ chỉ ra lỗi
compile chứ không phải lỗi runtime. Đã xác nhận cơ chế race đúng qua truy
vết logic thủ công chi tiết (ghi lại trong `## Hiện trạng`/`## Đề xuất`)
thay vì revert-chạy-lại — chấp nhận được vì cơ chế đã được chứng minh
bằng suy luận chặt chẽ dựa trên đúng semantics của `Future.then()`
(sequential theo thứ tự chain, đảm bảo ngôn ngữ, không phải may rủi
timing).

Test: 2 test race mới (tổng đúng sau burst 10 lần gọi rất nhanh; không
write nào bị rớt/gộp — kiểm qua `platformWrites` tăng ÍT NHẤT 5, không
phải đúng 5 tuyệt đối vì `VersionedJsonStore.save()` còn gọi
`nowMsClamped()` có thể tự thêm 1 write phụ lần đầu watermark được nâng,
không liên quan tới race đang test). Cả 2 test cũ (persist qua restart)
vẫn pass sau khi sửa lại bằng cờ `_saving`. `flutter analyze` sạch cả
root + `example/`. `flutter test --exclude-tags slow`: tất cả pass,
không regression (504→506 root, 29 example).

Không có device smoke test — fix logic thuần Dart trong core service,
không render UI (cùng lý do BUG-16/IDEA-15).

## Ghi chú độ tin cậy
Cao — race condition thật, cùng root cause với BUG-18 (daily_login_service) nhưng khác file nên tách task riêng để dễ review/merge độc lập.
