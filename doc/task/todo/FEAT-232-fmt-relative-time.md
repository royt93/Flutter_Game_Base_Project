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
