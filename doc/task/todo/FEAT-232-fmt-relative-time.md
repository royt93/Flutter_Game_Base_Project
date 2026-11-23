---
id: FEAT-232
title: "fmtRelative: thời gian tương đối ('vừa xong', '5 phút trước', 'hôm qua') theo locale, thuần hàm"
type: feature
layer: lib/core/utils
priority: P3
effort: S
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm

`lib/core/utils/format.dart` có `fmtDur` (mm:ss), `durationToLocalMidnight`, `fmtNum`; quét `lib` không có `timeAgo/relativeTime/fmtRelative`. `AppTranslations` hiện 2 locale (en, vi), có test ép parity key.

## Phạm vi đề xuất

- `String fmtRelative(DateTime then, {DateTime? now})`: hàm thuần, `now` truyền vào để test (không gọi `DateTime.now()` trực tiếp trong logic; mặc định dùng `nowMsClamped` hay đồng hồ gọi, chốt khi làm: ghi rõ UTC hay local và mốc "hôm qua" theo ngày nào, cùng vấn đề đã ghi ở ENH-114).
- Bậc: vừa xong (< 1 phút), N phút, N giờ, hôm qua, N ngày, rồi quay về ngày đầy đủ. Tương lai (`then` > `now`): trả "vừa xong" hoặc "sắp tới", chốt khi làm; không ném.
- Chuỗi qua `AppTranslations` (key mới thêm vào CẢ HAI locale, test parity bắt thiếu); số nhiều cho en ("1 minute" vs "2 minutes") có key riêng; vi không biến đổi số nhiều.
- Test: mọi ranh giới bậc (59s/60s, 59m/60m, 23h/24h), tương lai, `then` rất xa quá khứ, DST nếu dùng giờ local; mutation check.

## Phụ thuộc

Liên quan FEAT-222 (thêm ngôn ngữ): mỗi key mới phải được dịch ở mọi locale được thêm sau; ghi chú trong task đó khi làm. Số nhiều ở ngôn ngữ phức tạp (ar, ru...) NGOÀI phạm vi bản đầu.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `fmtRelative(DateTime then, {DateTime? now})` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. Chốt mốc "hôm qua": UTC hay giờ local (tham chiếu ENH-114), ghi vào dartdoc và test ranh giới ngày.
- [ ] 4. Thêm key dịch vào CẢ HAI locale trong `app_translations.dart` (số nhiều en có key riêng); `test/core/app_translations_test.dart` phải pass (parity).
- [ ] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mọi ranh giới bậc có test (59s/60s, 59m/60m, 23h/24h).
- [ ] `then` ở tương lai không ném.
- [ ] Không gọi `DateTime.now()` trực tiếp trong logic (nhận `now`).

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils test/core/app_translations_test.dart`
