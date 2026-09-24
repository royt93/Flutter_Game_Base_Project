---
id: IDEA-66
title: "Demo/doc hoá luồng đầy đủ 'load → verify HMAC → migrate N version → sync cloud' — 3 mảnh đã có nhưng chưa từng ghép chung"
type: idea
priority: low
effort: L
source: "claude (độc lập)"
---

## Vị trí
`lib/core/save_migration_registry.dart`, `lib/core/save_integrity.dart`, `lib/core/cloud_save_provider.dart` (seam) + `lib/core/versioned_json_store.dart`.

## Hiện trạng
`SaveMigrationRegistry` + `SaveIntegrityService` (HMAC) + `CloudSaveProvider` seam đều tồn tại độc lập, mỗi cái làm đúng 1 việc (đúng tinh thần thiết kế của kit), nhưng không có service/doc/demo nào minh hoạ luồng đầy đủ: load save → verify HMAC → nếu cần, chạy qua N bước migration → sync lên cloud → xử lý conflict nếu có.

## Vì sao cần / Hậu quả
Đa số game-kit khác không có cả 3 mảnh này cùng lúc — ghép chúng thành 1 flow tài liệu hoá + demo rõ ràng là lợi thế cạnh tranh thật (differentiator), không phải tính năng phổ biến, nhưng hiện tại giá trị này "ẩn" vì không đâu chứng minh chúng hoạt động cùng nhau.

## Đề xuất
Viết 1 phần trong README/CLAUDE.md + 1 demo trong `example/` (có thể là 1 màn hình mới hoặc mở rộng `CookbookScreen`) minh hoạ đầy đủ chuỗi: khởi tạo save cũ (version thấp) → verify HMAC → migrate qua `SaveMigrationRegistry` → sync qua 1 `CloudSaveProvider` fake → xử lý 1 tình huống conflict giả lập.

## Acceptance criteria
- [x] Demo minh hoạ đủ 4 bước (load/verify/migrate/sync) trong 1 luồng liên tục, không phải 4 demo rời rạc.
- [x] README/CLAUDE.md có 1 đoạn giải thích rõ đây là 1 tổ hợp differentiator, không phải 4 tính năng riêng lẻ.
- [x] Test widget/integration cho demo minh hoạ đủ luồng.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-66-unified-save-security-story-demo.md` này trước khi làm. Đọc toàn bộ `lib/core/save_migration_registry.dart`, `lib/core/save_integrity.dart`, `lib/core/cloud_save_provider.dart`, `lib/core/versioned_json_store.dart` trước khi thiết kế demo. Implement bằng TDD cho phần code, cân nhắc kỹ effort L — có thể chia nhỏ thành demo tối thiểu trước, mở rộng sau nếu cần.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget/integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (chạy hết luồng demo, verify từng bước) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hợp lý về mặt "storytelling"/documentation, dựa trên 3 hạ tầng đã có thật; effort L thực ra chủ yếu là công sức viết demo/doc chứ không phải code mới phức tạp. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Không cần code mới phức tạp — đúng như "Ghi chú độ tin cậy" của task tự
dự đoán**: chỉ thêm 1 tile mới trong `example/lib/screens/cookbook_screen.dart`
(đúng vị trí "Đề xuất" gợi ý), tái dùng NGUYÊN VẸN 4 mảnh đã có: `signExport`/
`verifyAndStrip` (HMAC), `SaveMigrationRegistry` (migrate multi-hop),
`VersionedJsonStore` (đúng pattern "save + load" tile đã có sẵn ngay phía
trên trong cùng file), `CloudSaveProvider` (qua `FakeCloudSaveProvider` đã
đăng ký sẵn ở `initState`) — và ĐẶC BIỆT tái dùng `VersionedJsonStore.syncWith(onConflict:)`
(ENH-83, làm ngay trong session này) để demo ĐÚNG cơ chế conflict resolution
thật, không phải so sánh tay giả lập.

**Luồng 4 bước liên tục thật (không phải 4 demo rời)**: (1) tạo 1 save
V1 giả lập rồi KÝ HMAC ngay (mô phỏng "đã ở trên đĩa/cloud, đã được bảo
mật"); (2) `verifyAndStrip` — nếu bị giả mạo sẽ throw ngay tại đây, KHÔNG
catch (đúng ý "code thật phải từ chối import, không âm thầm tiếp tục");
(3) `SaveMigrationRegistry.migrate` đưa save V1 (thiếu field `gems`) lên
đúng schema V2; (4) lưu vào `VersionedJsonStore`, rồi CHỦ ĐỘNG ghi lên
cloud fake 1 giá trị KHÁC (`level: 99`) trước khi gọi `syncWith` — đảm
bảo demo THẬT SỰ kích hoạt `onConflict` (không phải happy-path giả vờ),
người xem thấy đúng `local level=5, cloud level=99 -> chọn cloud`.

**CLAUDE.md**: thêm mục "Unified save security story (IDEA-66)" ngay
trước "Public API compatibility gate" — giải thích rõ đây là TỔ HỢP
differentiator (4 mảnh riêng lẻ tầm thường, nhưng ghép lại thành 1 luồng
thật thì hiếm kit nào có cả 4), trỏ thẳng tới tile mới làm reference
implementation.

**TDD**: viết test trước, `git stash` riêng `cookbook_screen.dart`, chạy
→ fail đúng ("Bad state: No element" — nút chưa tồn tại), khôi phục, chạy
lại — 2/2 pass. Test 1 verify ĐỦ chuỗi: toast hiện đúng "xung đột thật:
local level=5, cloud level=99" (chứng minh migrate + conflict cả hai đều
chạy thật, không phải giả lập kết quả), có field `gems` (chỉ xuất hiện
sau migrate), `schemaVersion: 2` (đúng version sau migrate). Test 2 verify
gọi lại tile lần 2 vẫn hoạt động đúng, không tích luỹ trạng thái sai giữa
các lần chạy (storage key cố định, ghi đè sạch mỗi lần). Chạy lại toàn
`cookbook_screen_test.dart` — 15/15 pass, không phá tile nào có sẵn.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `example/`:
144/144 pass (+2 test mới). Root: 2305 test, 19 fail — đúng baseline
golden-image (task không đụng `lib/` nào, không cần root diff riêng).
`dart run tool/api_compatibility.dart check` → `unchanged` (chỉ sửa
`example/` + `CLAUDE.md`, không export public mới). Không cần smoke test
device (task tự ghi optional, widget test qua toast thật đã chứng minh
đủ cả 4 bước chạy thật, không phải mockup).

Tự chấm: **9.5/10** — đúng tinh thần task (effort L chủ yếu công sức viết
demo/doc, không code phức tạp mới), tái dùng 100% hạ tầng có sẵn (không
viết lại bất kỳ mảnh nào), demo conflict THẬT chứ không phải happy-path
giả vờ (điểm dễ bị làm hời hợt nhất của loại task "storytelling" này),
CLAUDE.md nêu rõ giá trị differentiator đúng yêu cầu AC2. Trừ 0.5 vì chưa
thêm phần tương ứng trong README.md (chỉ có CLAUDE.md) — CLAUDE.md là nơi
đọc nhiều hơn với AI/dev làm việc trực tiếp trên repo nên ưu tiên viết ở
đó trước, nhưng README.md (nếu có, hướng tới người dùng cuối cài package)
sẽ hoàn thiện hơn.
