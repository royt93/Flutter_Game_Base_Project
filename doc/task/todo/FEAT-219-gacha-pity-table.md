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

- [ ] 1. Chốt API `PityTable<T>` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. Chốt soft vs hard pity (đề xuất: ngưỡng cứng) và ghi vào README đoạn "chỉ là công cụ xác suất, không phải tư vấn pháp lý; không có UI mua".
- [ ] 4. `toJson/fromJson` qua `safe_json` (trường sai kiểu rơi về mặc định) + test round trip qua `VersionedJsonStore`.
- [ ] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Không bao giờ vượt `pityAfter` lần trượt liên tiếp (test chạy hàng chục nghìn lần với nhiều seed).
- [ ] Cùng seed cho cùng chuỗi kết quả; save rồi tiếp tục cho cùng chuỗi.
- [ ] Bộ đếm reset đúng sau khi ra hạng bảo hiểm.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`
