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

- [x] 1. Chốt API `fmtRelative(DateTime then, {DateTime? now})` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [x] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [x] 3. Chốt mốc "hôm qua": UTC hay giờ local (tham chiếu ENH-114), ghi vào dartdoc và test ranh giới ngày.
- [x] 4. Thêm key dịch vào CẢ HAI locale trong `app_translations.dart` (số nhiều en có key riêng); `test/core/app_translations_test.dart` phải pass (parity).
- [x] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [x] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [x] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [x] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Mọi ranh giới bậc có test (59s/60s, 59m/60m, 23h/24h).
- [x] `then` ở tương lai không ném.
- [x] Không gọi `DateTime.now()` trực tiếp trong logic (nhận `now`).

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils test/core/app_translations_test.dart`

## Kết quả thực hiện (2026-11-23)

- Quyết định (dùng mặc định đề xuất, owner chọn "dùng mặc định đề xuất, ghi rõ"): bậc theo THỜI GIAN TRÔI QUA, không theo ngày lịch hay múi giờ, nên DST và câu hỏi UTC/local (ENH-114) không dịch được ranh giới. `< 1 phút` = "Vừa xong", `< 1 giờ` đếm phút, `< 24 giờ` đếm giờ, `24 đến < 48 giờ` = "Hôm qua", từ đó đếm ngày (không quay về ngày đầy đủ: ngày đầy đủ cần định dạng ngày theo locale, ngoài phạm vi bản đầu). `then` ở tương lai = "Vừa xong". Không ném.
- Mốc "hôm qua" nghĩa là 24-48 giờ trước (không phải "ngày lịch hôm qua"): ghi trong dartdoc. Game cần "ngày lịch" phải tự làm.
- Số nhiều: en có key riêng cho 1 (`rel_minute`, `rel_hour`) và nhiều (`rel_minutes`, `rel_hours`, `rel_days`); `rel_days` không có dạng "1 day" vì 1 ngày là "Hôm qua". vi cũng có đủ cả 5 key (`rel_minute` và `rel_minutes`, `rel_hour` và `rel_hours`...) để giữ parity key en/vi; chuỗi vi cho 1 và nhiều chỉ khác chữ số ("1 phút trước", "@n phút trước"). Ngôn ngữ có số nhiều phức tạp (ar, ru) ngoài phạm vi (FEAT-222).
- 8 key mới `rel_*` ở cả hai locale; `app_translations_test` (parity) pass.
- Test: 5 test trong `format_test.dart` (mọi ranh giới en, vi, tương lai, 36500 ngày không ném, DST 2026-03-08). Mutation: dịch ranh giới phút làm 2 test đỏ, bỏ nhánh "hôm qua" làm 3 đỏ, bỏ key vi làm 3 đỏ (kể cả parity), bỏ dạng số ít làm 1 đỏ.
- Kiểm chứng: analyze sạch, root 4144 pass, API snapshot đã cập nhật (thêm `fmtRelative`), CHANGELOG `## Unreleased`. Quality-gate (5 tool) chạy xanh sau thay đổi này.
- Chưa làm: định dạng ngày đầy đủ khi quá lâu; thêm key cho ngôn ngữ mới (FEAT-222 phải dịch 8 key này).
