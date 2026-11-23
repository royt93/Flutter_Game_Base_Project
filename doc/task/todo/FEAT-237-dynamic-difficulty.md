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

- [ ] 1. Chốt công thức (cửa sổ trượt: tỉ lệ thắng gần nhất so với ngưỡng mục tiêu, vd 50%) và ghi vào dartdoc kèm ví dụ số; trả lời "Câu hỏi mở" (không có owner thì dùng "Đề xuất" và nêu rõ).
- [ ] 2. Viết test đỏ: chuỗi thắng liên tiếp tăng độ khó đến `max` rồi dừng; chuỗi thua giảm đến `min` rồi dừng; thắng/thua xen kẽ nằm trong `deadband` không đổi; `window` chưa đầy; `record` nhiều lần cho cùng kết quả mỗi lần chạy.
- [ ] 3. Cài đặt thuần Dart + `ArgumentError` cho tham số sai + `toJson/fromJson` (test round trip và JSON hỏng/sai kiểu rơi về mặc định).
- [ ] 4. Mutation check (bỏ kẹp `max`, test đỏ; bỏ `deadband`, test đỏ).
- [ ] 5. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 6. README/dartdoc: đoạn "công cụ cân bằng, không dùng để ép chi tiêu". Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Độ khó luôn trong `[min, max]` với mọi chuỗi thắng/thua (test ngẫu nhiên có seed, hàng nghìn bước).
- [ ] Xen kẽ thắng/thua trong `deadband` không làm độ khó dao động.
- [ ] Lưu rồi khôi phục cho cùng chuỗi giá trị về sau.
- [ ] Tham số sai là `ArgumentError`.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`
