---
id: FEAT-219
title: "Gacha/pity helper: bảng loot có bảo hiểm sau N lần không ra hiếm, seeded, serializable"
type: feature
layer: lib/core
priority: P3
effort: S
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Kit có `weightedRandomPick` và `CompiledWeightedTable<T>` (utils) nhưng không có bảo hiểm (pity). Quét `lib`: chỉ có một nhắc "gacha" trong doc của `weighted_random_pick.dart`.

## Phạm vi đề xuất

- `PityTable<T>` thuần Dart: bảng trọng số + quy tắc "sau `pityAfter` lần liên tiếp không ra hạng `rare` thì lần kế tiếp ép ra", bộ đếm trạng thái có `toJson/fromJson` (đi qua `VersionedJsonStore`), nhận `Random` (SeededRandom) để tái lập.
- Validate bằng `ArgumentError` ở constructor (trọng số > 0, `pityAfter` > 0, hạng bảo hiểm có trong bảng) theo ENH-85; JSON không tin cậy đi qua `safe_json`.
- Test: đảm bảo không bao giờ vượt `pityAfter` lần trượt, bộ đếm reset đúng sau khi ra, tái lập với cùng seed, round-trip save; mutation check.

## Rủi ro đã nêu

Loot box có quy định theo từng vùng (tỉ lệ công bố, tuổi). README/doc phải ghi: đây chỉ là công cụ xác suất, không phải tư vấn pháp lý; không có UI mua.

## Câu hỏi mở

Một hay nhiều hạng bảo hiểm (soft/hard pity), có "tỉ lệ tăng dần" kiểu soft pity hay chỉ ngưỡng cứng. Đề xuất: ngưỡng cứng ở bản đầu.

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Chốt API `PityTable<T>` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [x] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [x] 3. Chốt soft vs hard pity (đề xuất: ngưỡng cứng) và ghi vào README đoạn "chỉ là công cụ xác suất, không phải tư vấn pháp lý; không có UI mua".
- [x] 4. `toJson/fromJson` qua `safe_json` (trường sai kiểu rơi về mặc định) + test round trip qua `VersionedJsonStore`.
- [x] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [x] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [x] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [x] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Không bao giờ vượt `pityAfter` lần trượt liên tiếp (test chạy hàng chục nghìn lần với nhiều seed).
- [x] Cùng seed cho cùng chuỗi kết quả; save rồi tiếp tục cho cùng chuỗi.
- [x] Bộ đếm reset đúng sau khi ra hạng bảo hiểm.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`

## Kết quả thực hiện (2026-11-23)

- Quyết định (dùng mặc định đề xuất, owner chọn "dùng mặc định đề xuất, ghi rõ"): NGƯỠNG CỨNG (không có soft pity); một tập `pityItems` (nhiều hạng bảo hiểm cùng lúc được, bất kỳ hạng nào trong tập cũng reset bộ đếm). Lần kéo thứ `pityAfter` sau chuỗi trượt bị ép chọn trong `pityItems`, theo trọng số gốc giữa chúng.
- API: `PityTable<T>({items, weights, pityItems, pityAfter})`, `pull(Random)`, `misses`, `toJson()`, `restore(Map)`, `items`, `weights`. Tái dùng `CompiledWeightedTable` (không viết lại bộ chọn). `pity_table.dart` ở `lib/core/utils/`, export từ `roy_casual_kit.dart`.
- Validate bằng `ArgumentError` (ENH-85): `pityAfter > 0`, `pityItems` không rỗng và đều thuộc `items`, `items` không trùng (trùng làm "hạng" mơ hồ), trọng số hữu hạn >= 0 và tổng > 0 (do `CompiledWeightedTable`), tổng trọng số của `pityItems` > 0.
- `restore` chịu mọi thứ: thiếu/sai kiểu/âm/NaN về 0; quá lớn kẹp về `pityAfter - 1` để save hỏng không bao giờ phá bảo đảm. Không đi qua `VersionedJsonStore` trong lib (chỉ cung cấp `toJson/restore`; game tự lưu), vì bộ đếm là một số nguyên, `safe_json` thừa.
- README ghi rõ (và thêm một dòng cho `UndoStack` của FEAT-216, trước đó chưa có trong README): công cụ xác suất, không có mua/UI, quy định tỉ lệ loot box khác nhau theo vùng, không phải tư vấn pháp lý.
- Test: 10 test (validate 3, hành vi 7: không bao giờ vượt `pityAfter` trên 40 seed x 3000 lần kéo, đúng lần thứ `pityAfter` bị ép, reset, tái lập cùng seed, lưu rồi tiếp tục cho cùng chuỗi, `restore` rác, thống kê tỉ lệ 9-13%). Mutation: lệch một làm 2 đỏ, không reset 4 đỏ, không đếm 3 đỏ, không kẹp khi restore 1 đỏ, cho phép trùng 1 đỏ, không ép pity 2 đỏ.
- Kiểm chứng: analyze sạch, root 4162 pass, API snapshot thêm `PityTable` (+6 dòng), CHANGELOG `## Unreleased`, 5 quality-gate xanh.
- Chưa làm: soft pity (xác suất tăng dần), nhiều bảo hiểm với ngưỡng khác nhau; ghi lại nếu cần.
