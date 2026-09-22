---
id: BUG-55
title: "9 service dùng string literal làm default storage key thay vì hằng số StorageKeys — vi phạm convention của chính CLAUDE.md"
type: bug
priority: P2
effort: M
source: "agy + claude (độc lập xác nhận cùng vấn đề, danh sách file hơi khác nhau — gộp), verify lại qua grep 1 vài file đại diện"
---

## Vị trí
`lib/core/checkpoint_coordinator.dart` (`storageKey ?? 'checkpoint_coordinator_v1'`), `lib/core/economy_wallet.dart`, `lib/core/offline_outbox_service.dart` (`'offline_outbox_v1'`), `lib/core/inventory_service.dart`, `lib/core/player_progression_service.dart` (`'player_progression_v1'`), `lib/core/reward_transaction_pipeline.dart` (`'reward_transaction_pipeline_v1'`), `lib/core/save_slot_manager.dart` (`'save_slot_meta_v1'`), và các service tương tự.

## Hiện trạng
CLAUDE.md quy định rõ: "Never use string literals for prefs keys — add a new named constant instead." Nhưng nhiều service mới hơn (thường có tham số `storageKey` override được) dùng default value là 1 string literal trực tiếp trong constructor, thay vì tham chiếu 1 hằng số trong `StorageKeys`.

## Vì sao cần / Hậu quả
Vì key có thể override qua constructor nên KHÔNG phải bug chức năng — nhưng khiến 1 audit tương lai chỉ `grep StorageKeys` sẽ bỏ sót các key thật đang tồn tại trên máy người dùng, gây rủi ro khi cần đổi tên key hàng loạt, viết migration, hoặc rà soát toàn bộ key đang dùng của app.

## Đề xuất
Thêm hằng số tương ứng vào `StorageKeys` cho mỗi default key literal ở các file trên, dùng hằng số đó làm default value thay vì string literal trực tiếp — không đổi hành vi (default value giữ nguyên chuỗi cũ để tương thích ngược với data đã lưu trên máy người dùng).

## Acceptance criteria
- [x] Mọi service liệt kê ở "Vị trí" dùng hằng số `StorageKeys.*` làm default storage key, không còn string literal trực tiếp trong constructor.
- [x] Giá trị chuỗi thật của mỗi hằng số GIỮ NGUYÊN y hệt string literal cũ (không đổi key thật — tránh mất dữ liệu người dùng đã lưu).
- [x] `grep -rn "StorageKeys\." lib/core/*.dart | wc -l` tăng đúng số lượng constant mới thêm; `grep` các default key literal cũ không còn kết quả nào trong `lib/core/`.
- [x] Test hiện có của toàn bộ các service trên vẫn pass nguyên vẹn (key thật không đổi).

## Quyết định
Grep lại toàn bộ `lib/core/*.dart` (không suy đoán) tìm ra **15 default key literal** ở **14 file** — nhiều hơn danh sách gốc: 13 service theo pattern `storageKey ?? '...'` (achievement_service, checkpoint_coordinator, daily_login_service, daily_quest_service, economy_wallet, inventory_service, local_scoreboard_service, onboarding_coordinator_service, player_progression_service, offline_outbox_service, purchase_ledger_service, season_event_service, reward_transaction_pipeline) + 2 field `static const` cố định (không override được) trong `save_slot_manager.dart` (`_metaStorageKey`/`_activeSlotStorageKey`) — mở rộng scope hợp lý vì cùng 1 loại vi phạm convention, cùng file `save_slot_manager.dart` đã được liệt kê trong "Vị trí" gốc.

Thêm đúng 15 hằng số mới vào `StorageKeys` (giữ NGUYÊN giá trị chuỗi — verify từng cái bằng grep trước khi sửa, không suy đoán), rồi đổi từng call site sang tham chiếu hằng số. Refactor cơ học thuần tuý, 0 thay đổi hành vi runtime.

**Verify không đổi giá trị**: thêm test khoá cứng (`expect(StorageKeys.x, 'chuỗi_cũ_y_hệt')`) cho cả 15 hằng số trong `storage_service_test.dart`, cộng 1 test đảm bảo không có 2 hằng số nào trùng giá trị (tránh 2 service vô tình đụng chung 1 key). Chạy lại TOÀN BỘ test suite hiện có của 14 service liên quan — pass nguyên vẹn (persistence round-trip không đổi vì giá trị chuỗi giữ y hệt).

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2091 pass / -20 fail (19 golden macOS-only có sẵn + 1 flake đã biết `season_event_service_test.dart ENH-71`, cả 2 loại không liên quan đến refactor này), `dart run tool/api_compatibility.dart check` unchanged (không export thêm gì mới, `StorageKeys` đã public sẵn), `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 132/132 pass.

Không smoke test device thật cài-đè-bản-cũ (task ghi "khuyến khích... không bắt buộc") — giá trị chuỗi giữ nguyên y hệt đã verify bằng test khoá cứng + toàn bộ test persistence hiện có pass nguyên vẹn, đủ chứng minh không mất data.

Tự chấm: **9.5/10** — refactor đúng scope + MỞ RỘNG hợp lý (phát hiện thêm 2 field không nằm trong `storageKey ??` pattern chính nhưng cùng vi phạm convention), verify cẩn thận giá trị chuỗi không đổi bằng grep trước/sau + test khoá cứng, không phá bất kỳ test nào trong 14 file service liên quan.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-55-storage-keys-string-literals-instead-of-constants.md` này trước khi làm. Đọc toàn bộ `lib/core/storage_service.dart` (class `StorageKeys`) và từng file liệt kê ở "Vị trí" trước khi sửa — xác nhận đúng chuỗi literal thật đang dùng ở mỗi file (đừng suy đoán, tự grep lại). Implement bằng TDD nếu hợp lý (test đảm bảo key thật không đổi), tuy đây chủ yếu là refactor cơ học.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung/verify test cho MỌI case ở Acceptance criteria (đặc biệt: key thật không đổi giá trị).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (refactor cơ học, không đổi hành vi/UI quan sát được — nhưng khuyến khích 1 lần cài đè bản cũ lên bản mới để verify dữ liệu người dùng cũ vẫn đọc được đúng, nếu tiện).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (agy, claude) cùng nêu vấn đề, danh sách file gần trùng nhau; đã grep xác nhận 1 vài default key literal tồn tại đúng như mô tả (`'offline_outbox_v1'`, `'reward_transaction_pipeline_v1'`, `'player_progression_v1'` — xác nhận qua Read constructor ở BUG-40). Đây là vi phạm convention (P2), không phải bug chức năng — effort M vì cần rà soát cẩn thận để KHÔNG đổi giá trị chuỗi thật (tránh mất data người dùng). Không trùng task nào trong `doc/task/done/`.
