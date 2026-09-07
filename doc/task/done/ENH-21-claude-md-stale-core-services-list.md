---
id: ENH-21
title: "CLAUDE.md's 'Core services' list thiếu 9 file đã tồn tại thật trong lib/core/"
type: enhance
priority: P2
effort: S
source: Claude, đề xuất feature mới (round 5), phát hiện phụ khi tra cứu trước khi đề xuất feature mới
---

## Vị trí
`CLAUDE.md` — mục "### 1. Core services (`lib/core/`, `lib/core/utils/`)".

## Hiện trạng
Mục này liệt kê từng file trong `lib/core/`/`lib/core/utils/` kèm mô tả
ngắn, nhưng khi đối chiếu với `ls lib/core/` thực tế, các file sau **có
tồn tại và có nội dung thật** nhưng KHÔNG có trong danh sách:
- `lib/core/achievement_service.dart` — `AchievementService extends GetxService`.
- `lib/core/analytics_provider.dart` — seam `AnalyticsProvider` (abstract) + `NoopAnalyticsProvider`.
- `lib/core/remote_config_service.dart` — `RemoteConfigService extends GetxService`.
- `lib/core/save_integrity.dart` — lớp HMAC checksum trên `StorageService.exportAll()/importAll()`.
- `lib/core/in_app_review_helper.dart` — logic quyết định khi nào hỏi rate app.
- `lib/core/utils/safe_json.dart` — `asIntOr`/`asStringOr`/`asDoubleOr`.
- `lib/core/utils/throttle.dart` — `throttled(VoidCallback, {Duration window})`.
- `lib/core/utils/weighted_random_pick.dart` — `weightedRandomPick<T>(...)`.

(`cloud_save_provider.dart`, `crash_reporter.dart`, `offline_progression_service.dart`,
`versioned_json_store.dart`, `performance_tier_service.dart`,
`daily_login_service.dart`, `energy_service.dart` ĐÃ có trong danh sách —
chỉ 8 file trên là thiếu.)

## Hậu quả
CLAUDE.md là tài liệu đầu tiên mọi phiên Claude Code mới đọc để hiểu
codebase — thiếu 8/~30 file cốt lõi nghĩa là 1 phiên mới có nguy cơ không
biết các service này tồn tại, dẫn tới việc đề xuất/viết lại 1 thứ đã có sẵn
(suýt xảy ra ở chính round đề xuất feature mới này — phải tự tra `ls
lib/core/` để phát hiện ra `AchievementService`/`PurchaseSeam`-tương-đương
đã có trước khi viết `IDEA-15`).

## Đề xuất fix
Thêm 8 bullet còn thiếu vào mục "Core services", theo đúng format 1 dòng
mỗi file các bullet hiện có đang dùng (tên class + 1 câu mô tả ngắn).

## Acceptance criteria
- [x] Toàn bộ file `.dart` trong `lib/core/` và `lib/core/utils/` có ít nhất 1 dòng mô tả trong CLAUDE.md.
- [x] Không lặp lại mô tả file đã có, giữ nguyên style hiện tại.

## Quyết định
Thực tế thiếu nhiều hơn mô tả ban đầu của task (grep lại toàn bộ tên file trong
CLAUDE.md: 0 kết quả cho cả 15 file, không phải 8 — các file
`offline_progression_service`/`versioned_json_store`/`performance_tier_service`/
`daily_login_service`/`energy_service`/`crash_reporter`/`cloud_save_provider`
cũng thiếu hoàn toàn, không phải "đã có" như giả định sai ban đầu). Thêm đủ 15
bullet còn thiếu (`offline_progression_service`, `versioned_json_store`,
`performance_tier_service`, `daily_login_service`, `energy_service`,
`achievement_service`, `save_integrity`, `in_app_review_helper`, 4 seam
(`crash_reporter`/`analytics_provider`/`cloud_save_provider`/
`remote_config_service`), `utils/safe_json`, `utils/throttle`,
`utils/weighted_random_pick`). Nhân tiện sửa luôn mục "### 2. Widgets" —
cũng stale tương tự (nói "21 widget", chỉ liệt kê 4 nhóm/~16 widget; thực
tế 40 widget, 6 nhóm). Viết lại khớp chính xác với
`common_widgets.dart` (5+10+12+9+1+3 = 40, đã đếm lại bằng `cat` file
thật, không suy đoán).
