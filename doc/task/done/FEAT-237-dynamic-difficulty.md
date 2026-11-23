---
id: FEAT-237
title: "DynamicDifficulty: điều chỉnh độ khó theo chuỗi thắng/thua gần đây, kẹp [min, max], có đệm, serializable"
type: feature
layer: lib/core
priority: P3
effort: S
source: "Đề xuất của Claude 2026-11-23 (game logic), owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm

Grep difficulty/DDA trong `lib`: không có. Match-3 demo dùng bảng level cố định (`Match3Config.levels`). `ExperimentBucketingService` có sẵn để A/B cách điều chỉnh.

## Rủi ro đã nêu

Độ khó ngầm gắn với mua hàng có thể bị coi là thao túng. Task này CHỈ là công cụ cân bằng thuần Dart; README/dartdoc ghi rõ không dùng để ép chi tiêu và không có liên kết với ví/IAP.

## Phạm vi đề xuất

- `DynamicDifficulty({min, max, start, step, window, deadband})` thuần Dart, không Flutter: `record(won: bool)` cập nhật điểm độ khó dựa trên `window` kết quả gần nhất, kẹp trong `[min, max]`, `deadband` (vùng đệm) để không đổi liên tục khi thắng/thua xen kẽ; `value` đọc độ khó hiện tại; `toJson/fromJson` (qua `safe_json`, trường sai kiểu rơi về mặc định).
- Validate bằng `ArgumentError` (ENH-85): `min <= max`, `start` trong khoảng, `step > 0`, `window > 0`, `deadband >= 0`.
- Deterministic: không dùng ngẫu nhiên.

## Câu hỏi mở

Độ khó là số thực hay số nguyên bậc. Đề xuất: số thực trong `[min, max]`, game tự ánh xạ sang bậc.

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Chốt công thức (cửa sổ trượt: tỉ lệ thắng gần nhất so với ngưỡng mục tiêu, vd 50%) và ghi vào dartdoc kèm ví dụ số; trả lời "Câu hỏi mở" (không có owner thì dùng "Đề xuất" và nêu rõ).
- [x] 2. Viết test đỏ: chuỗi thắng liên tiếp tăng độ khó đến `max` rồi dừng; chuỗi thua giảm đến `min` rồi dừng; thắng/thua xen kẽ nằm trong `deadband` không đổi; `window` chưa đầy; `record` nhiều lần cho cùng kết quả mỗi lần chạy.
- [x] 3. Cài đặt thuần Dart + `ArgumentError` cho tham số sai + `toJson/fromJson` (test round trip và JSON hỏng/sai kiểu rơi về mặc định).
- [x] 4. Mutation check (bỏ kẹp `max`, test đỏ; bỏ `deadband`, test đỏ).
- [x] 5. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [x] 6. README/dartdoc: đoạn "công cụ cân bằng, không dùng để ép chi tiêu". Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Độ khó luôn trong `[min, max]` với mọi chuỗi thắng/thua (test ngẫu nhiên có seed, hàng nghìn bước).
- [x] Xen kẽ thắng/thua trong `deadband` không làm độ khó dao động.
- [x] Lưu rồi khôi phục cho cùng chuỗi giá trị về sau.
- [x] Tham số sai là `ArgumentError`.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`

## Kết quả thực hiện (2026-11-23)

- Quyết định (dùng mặc định đề xuất): độ khó là số thực trong `[min, max]`, game tự ánh xạ sang bậc/tốc độ. Công thức: sau mỗi `record`, khi đã đủ `window` kết quả, so số thắng trong `window` kết quả mới nhất với `(targetWinRate ± deadband) * window`: vượt biên trên thì `+step`, dưới biên dưới thì `-step`, trong dải thì giữ; luôn kẹp `[min, max]`. Mặc định `targetWinRate = 0.5`, `deadband = 0.1`. Biên là KHÔNG-bao-gồm (đúng biên thì giữ).
- API: `DynamicDifficulty({min, max, start, step, window, deadband = 0.1, targetWinRate = 0.5})`, `record({required bool won})`, `value`, `toJson()`, `restore(Map)`. `targetWinRate` là tham số thêm so với đề xuất ban đầu (công thức cần một mục tiêu, trước đó ngầm định 50%).
- Validate bằng `ArgumentError` (ENH-85): mọi số hữu hạn, `min <= max`, `start` trong khoảng, `step > 0`, `window > 0`, `deadband >= 0`, `targetWinRate` trong (0, 1). `restore` chịu mọi thứ: giá trị thiếu/NaN về `start`, ngoài khoảng bị kẹp, kết quả sai kiểu bị bỏ, chỉ giữ `window` kết quả mới nhất.
- **Lỗi bắt được nhờ test biên (không thấy khi đọc code):** bản đầu so TỈ LỆ (`rate > target + deadband`). Trong dấu phẩy động `0.7 + 0.1 = 0.7999999999999999` nên tỉ lệ đúng 0.8 bị coi là vượt biên, test `targetWinRate` khác mặc định đỏ. Sửa: so SỐ LẦN THẮNG với `(target ± deadband) * window` cộng epsilon 1e-9 (nhỏ hơn mọi `1/window` có nghĩa). Bỏ epsilon làm 1 test đỏ.
- Mutation (sau khi sửa): bỏ deadband trên/dưới làm 2 đỏ mỗi nhánh, kẹp khi record 4 đỏ, bỏ chờ cửa sổ đầy 4 đỏ, bỏ epsilon 1 đỏ, nới biên một nửa lần thắng 3 đỏ. Hai biến đổi (đổi `>` thành `>=` ở biên) sống sót KHI CÓ epsilon vì epsilon làm hai dạng tương đương về số học; khi bỏ cả epsilon thì cùng biến đổi bị bắt (2 đỏ). Đó là biến đổi tương đương, không phải lỗ hổng test.
- Test: 16 test (validate 3, hành vi 13: chờ đầy cửa sổ, chuỗi thắng/thua chạm min/max, xen kẽ trong dải, biên trên và dưới đúng/lệch một, `targetWinRate` khác, phục hồi, ngẫu nhiên có seed 25 x 2000 bước luôn trong khoảng, xác định, lưu/khôi phục cùng quỹ đạo, `restore` rác, giữ `window` mới nhất).
- README ghi rõ: công cụ cân bằng, không liên kết ví/mua hàng, không dùng để ép chi tiêu.
- Kiểm chứng: analyze sạch, root 4178 pass, API snapshot thêm `DynamicDifficulty` (+6 dòng), CHANGELOG `## Unreleased`, 5 quality-gate xanh.
- Chưa làm: chưa dùng `ExperimentBucketingService` để A/B công thức (chỉ nêu khả năng); không có tích hợp vào Match-3 demo.
