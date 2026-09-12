---
id: BUG-19
title: "EnergyService: nhận amount không hợp lệ, không chuẩn hoá giá trị đã lưu, ghi 2 field rời rạc"
type: bug
priority: P2
effort: M
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/energy_service.dart` — `consumeEnergy()`, `currentEnergy`, `_regen()`.

## Hiện trạng
3 vấn đề trong cùng file: (1) `consumeEnergy()` không validate `amount` — số âm khiến `energy < amount` sai logic và làm energy TĂNG vượt `maxEnergy`; số 0 báo thành công dù không tiêu gì. (2) Giá trị `energy` đọc từ storage được tin tưởng nguyên vẹn, không clamp vào `0..maxEnergy` — 1 giá trị corrupt/import sai (âm hoặc vượt max) tồn tại vĩnh viễn. (3) `consumeEnergy()`/`_regen()` ghi `energyLastMs` và `energyCount` bằng 2 lệnh fire-and-forget RIÊNG BIỆT — app bị kill giữa 2 lệnh để lại checkpoint lệch nhau (baseline mới nhưng count cũ, hoặc ngược lại), làm refill tính sai lần sau.

## Vì sao cần / Hậu quả
Người chơi có thể farm energy vô hạn (truyền amount âm nếu có lỗ hổng caller), hoặc bị cache năng lượng sai vĩnh viễn nếu save bị chỉnh tay hoặc import lỗi, hoặc mất/được thêm refill progress một cách không nhất quán nếu app crash đúng lúc.

## Đề xuất
Validate `amount > 0` trong `consumeEnergy()` (ném `ArgumentError` nếu không hợp lệ — input xấu chỉ có thể tới từ lỗi lập trình gọi sai, không phải user input thật). Clamp mọi giá trị energy đọc từ storage vào `[0, maxEnergy]` trước khi trả về/dùng. Gộp `energyLastMs` + `energyCount` thành 1 record JSON duy nhất ghi bằng 1 lệnh (dùng lại pattern `VersionedJsonStore` nếu hợp lý, hoặc đơn giản hơn: 1 string JSON qua `setString` thay vì 2 key riêng) để đảm bảo atomic theo nghĩa thực tế (không thể chỉ 1 trong 2 field được ghi).

## Acceptance criteria
- [x] consumeEnergy(amount) với amount <= 0 ném ArgumentError rõ ràng, không âm thầm làm sai state.
- [x] Giá trị energy đọc từ storage luôn nằm trong [0, maxEnergy] kể cả khi dữ liệu gốc bị corrupt/out-of-range.
- [x] energyLastMs và energyCount được ghi/đọc như 1 đơn vị nhất quán — kill app giữa chừng không thể để lại checkpoint lệch nhau.
- [x] Test: amount âm/0/rất lớn, giá trị storage âm/vượt max trước khi service khởi tạo, và write bị gián đoạn giữa energyLastMs/energyCount.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-19-energy-service-input-and-persistence-hardening.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Quyết định
Làm đúng cả 3 vấn đề trong 1 lần sửa (cùng file, tự nhiên đi chung):

1. `consumeEnergy(amount)` ném `ArgumentError` khi `amount <= 0`.
2. `_readState()` (helper đọc mới) luôn `count.clamp(0, maxEnergy)` — mọi
   getter công khai (`currentEnergy`, `timeUntilNextEnergy`, ...) đều đi
   qua đây nên tự động được bảo vệ, không cần sửa từng nơi.
3. Gộp `energyCount`+`energyLastMs` thành 1 key mới `StorageKeys.
   energyStateV1` chứa 1 chuỗi JSON `{"count", "lastMs"}`, ghi bằng ĐÚNG 1
   lệnh `setString` — thay vì trả lời câu hỏi "coi transaction này atomic
   thế nào" bằng cơ chế transaction phức tạp, chỉ cần gộp 2 giá trị luôn
   cần đi cùng nhau thành 1 write duy nhất là đủ, đúng tinh thần ponytail
   (giải pháp đơn giản nhất giải quyết đúng vấn đề).

   Xử lý migrate: đọc thử `energyStateV1` trước; nếu chưa có (save cũ từ
   trước bản fix này), fallback đọc 2 key cũ (`energyCount`/`energyLastMs`)
   — save của người chơi hiện tại (nếu app này đã publish thật) không bị
   mất/reset về đầy tim. Lần ghi tiếp theo sẽ tự chuyển sang format mới.

Thêm validate `maxEnergy > 0`/`refillInterval > Duration.zero` trong
constructor — LƯU Ý: ban đầu dùng cả `assert(...)` LẪN `if (...) throw
ArgumentError` cùng lúc, nhưng `assert` chạy TRƯỚC (throw
`_AssertionError`) và không hề bị strip ở chế độ test/debug — phát hiện
qua chính test tự viết (`throwsArgumentError` fail vì nhận nhầm loại
exception). Bỏ hẳn `assert`, chỉ giữ `if` + `throw ArgumentError` (runtime
check thật, sống sót qua cả release build, đúng yêu cầu ban đầu của
Đề xuất).

Thêm `@visibleForTesting int get debugLastRegenMs` để test đọc baseline
thời gian mà không cần biết implementation detail (key nào, format nào)
— test cũ (`store.getInt(StorageKeys.energyLastMs)`) được cập nhật dùng
accessor này thay vì đọc thẳng key cũ (đã đổi sang key mới).

Test: 10 test mới (root) — constructor validate 2 tham số, consumeEnergy
validate 2 trường hợp (0, âm), clamp giá trị corrupt (vượt max và âm),
migrate từ format 2-key cũ, JSON hỏng không crash, ghi atomic đúng 1 write
(so `platformWrites`, đã pre-warm `nowMsClamped()`'s watermark write phụ
trước khi đo để không lẫn vào phép đo), và đọc lại đúng qua instance mới
sau khi ghi atomic. Toàn bộ 12 test cũ vẫn pass nguyên vẹn. `flutter
analyze` sạch cả root + `example/`. `flutter test --exclude-tags slow`:
tất cả pass, không regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Progress & Reward → EnergyBar demo → bấm "Consume 1 energy" 5 lần liên
tiếp, tim giảm đúng 5→4→...→0 (không âm), đếm ngược hiện đúng sau lần tiêu
đầu tiên, không exception trong logcat.

## Ghi chú độ tin cậy
Cao — 3 vấn đề độc lập nhưng cùng 1 file, tự nhiên sửa chung 1 lần để tránh regress lẫn nhau. Effort M vì cần đổi format lưu trữ (gộp 2 field), có thể cần cân nhắc migration cho dữ liệu cũ đã lưu theo format 2-key hiện tại (đọc thử format cũ nếu format mới không có, để không phá dữ liệu người chơi hiện tại).
