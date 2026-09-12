---
id: BUG-20
title: "VersionedJsonStore: không phòng thủ trước JSON local/cloud sai định dạng hoặc sai schema version"
type: bug
priority: P2
effort: L
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/versioned_json_store.dart` — `_readLocalJson()`, `load()`, `syncWith()`.

## Hiện trạng
3 vấn đề: (1) `_readLocalJson()` chạy thẳng `jsonDecode(raw) as Map<String, Object?>` và ép kiểu `schemaVersion` — JSON hỏng, JSON là list, hoặc version sai kiểu đều throw thẳng từ `load()`/`syncWith()` thay vì được xử lý như 1 trust-boundary bình thường (class này TỒN TẠI để xử lý save cũ/cloud — dữ liệu untrusted, không phải input nội bộ tin cậy). (2) `_readLocalJson()` chỉ migrate version THẤP HƠN `schemaVersion` hiện tại — 1 record với version CAO HƠN (ví dụ app bị hạ version) được đưa thẳng vào `fromJson` hiện tại mà không cảnh báo gì, có thể crash hoặc đọc sai dữ liệu. (3) `syncWith()` ép kiểu `syncedAtMs` trực tiếp và ghi đè local bằng cloud map nguyên văn nếu cloud mới hơn — không áp dụng lại cùng logic validate/migrate như đường đọc local, và không gọi `fromJson` để validate trước khi ghi đè.

## Vì sao cần / Hậu quả
1 save cũ bị hỏng (device crash giữa lúc ghi, hoặc người dùng chỉnh tay), hoặc 1 payload cloud sai định dạng/tương lai (từ 1 phiên bản app khác), có thể làm app crash ngay lúc boot/sync, hoặc worse: âm thầm ghi đè save hợp lệ bằng dữ liệu hỏng.

## Đề xuất
Bọc toàn bộ decode + validate trong try/catch, trả về null (hoặc trigger fallback tới `_DailyLoginState.initial`-style default tuỳ class dùng `VersionedJsonStore`) khi JSON không phải Map hợp lệ hoặc `schemaVersion` sai kiểu. Từ chối rõ ràng `storedVersion > schemaVersion` (không migrate xuống ngầm) trừ khi caller cung cấp chính sách downgrade tường minh. Áp dụng ĐÚNG cùng validate + migrate pipeline cho `syncWith()`'s cloud payload trước khi ghi đè local, thay vì ghi thẳng.

## Acceptance criteria
- [x] load()/syncWith() không throw khi gặp JSON hỏng/sai kiểu/list thay vì map — trả về fallback hợp lý theo policy đã tài liệu hoá rõ trong doc comment.
- [x] Record với schemaVersion CAO HƠN hiện tại bị từ chối/cách ly rõ ràng, không bị fromJson hiện tại xử lý nhầm.
- [x] syncWith() validate + migrate cloud payload giống hệt đường đọc local trước khi ghi đè, không ghi thẳng dữ liệu chưa qua fromJson.
- [x] Test: JSON hỏng, JSON là list, schemaVersion sai kiểu, schemaVersion tương lai, cloud timestamp sai kiểu, cloud schema cũ hơn/mới hơn local — xác nhận local data được giữ nguyên khi cloud payload không hợp lệ.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-20-versioned-json-store-untrusted-data-hardening.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Quyết định
Tách logic validate/migrate thành 1 hàm chung `_validate(Object? decoded)`
dùng LẠI y hệt cho cả `_readLocalJson()` (đọc local) lẫn `syncWith()`
(đọc cloud) — đúng tinh thần "cloud payload = untrusted y hệt local save"
đã nêu trong Đề xuất, không viết 2 bộ logic riêng dễ lệch nhau. Policy:
không phải `Map<String,Object?>` → null; `schemaVersion` (đọc qua
`asIntOr` có sẵn trong `utils/safe_json.dart`, không tự viết lại parser)
CAO HƠN hiện tại → null (từ chối, không đưa vào `migrate`/`fromJson`);
THẤP HƠN → chạy `migrate`; BẰNG → trả nguyên.

`syncWith()` thêm 1 bước nữa RIÊNG cho cloud (không cần cho local, vì
local luôn do chính `save()` của class này ghi ra): sau khi `_validate`
pass, còn gọi thử `fromJson(cloudJson)` trong try/catch trước khi ghi đè
local — vì `_validate` chỉ đảm bảo ENVELOPE (schemaVersion, cấu trúc map)
hợp lệ, không đảm bảo TỪNG FIELD bên trong đúng kiểu `T` cần (ví dụ
`level` là string thay vì int) — lỗi đó chỉ `fromJson` thật sự mới phát
hiện được.

Trong lúc viết test, phát hiện 1 lỗi TRONG CHÍNH TEST (không phải trong
code sản xuất): dùng timestamp tuyệt đối `999999999999` để mô phỏng "cloud
mới hơn" — con số này chỉ ~10^12, còn epoch ms thật năm 2026 đã ~1.76×10^12,
tức "tương lai giả" đó thực ra ĐANG Ở QUÁ KHỨ so với đồng hồ thật lúc test
chạy! Sửa lại dùng `DateTime.now().millisecondsSinceEpoch + 100000` (tương
đối, đúng convention đã có sẵn trong `cloud_save_provider_test.dart`) thay
vì hằng số tuyệt đối — bài học: không bao giờ hardcode 1 mốc "tương lai xa"
bằng số tuyệt đối, luôn tính tương đối theo đồng hồ thật lúc test chạy.

Test: 11 test mới (6 cho local `_readLocalJson`/`load`, 5 cho `syncWith`
cloud payload) — JSON hỏng, JSON là list, JSON là giá trị trần, schemaVersion
sai kiểu (coi như version 0, migrate an toàn), schemaVersion tương lai (từ
chối), thiếu field vẫn để `fromJson` tự throw (không phải trách nhiệm của
lớp validate envelope); cloud tương tự + thêm: cloud cũ hơn theo schema
nhưng mới hơn theo timestamp → migrate đúng rồi mới ghi đè; cloud field
sai kiểu khiến fromJson throw → không ghi đè; cloud timestamp sai kiểu →
coi như -1 (cũ nhất), không thắng local. Toàn bộ 9 test cũ (bao gồm
`cloud_save_provider_test.dart`) vẫn pass nguyên vẹn. `flutter analyze`
sạch cả root + `example/`. `flutter test --exclude-tags slow`: tất cả
pass, không regression.

Không có device smoke test riêng — đây là lớp lưu trữ nền tảng dùng bởi
`AchievementService`/`DailyLoginService`, không có UI trực tiếp; test
`DailyLoginCalendarWidget demo` trong `example/` (dùng chung
`VersionedJsonStore` qua `DailyLoginService`) đã chạy pass, xác nhận
tích hợp không bị phá vỡ. Các edge case cụ thể của task này (JSON hỏng,
schema tương lai) không phải thứ có thể thao tác qua UI thật để test có
ý nghĩa hơn unit test đã có.

## Ghi chú độ tin cậy
Cao — đây là lớp lưu trữ dùng cho save data quan trọng nhất (player profile/level progress theo CLAUDE.md), phòng thủ kém ở đây rủi ro cao nhất trong toàn bộ audit. Effort L vì đụng tới cả local read path lẫn cloud sync path, cần thiết kế policy rõ ràng (không chỉ patch từng chỗ) và nhiều test case.
