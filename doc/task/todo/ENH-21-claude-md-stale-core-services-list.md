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
- [ ] Toàn bộ file `.dart` trong `lib/core/` và `lib/core/utils/` có ít nhất 1 dòng mô tả trong CLAUDE.md.
- [ ] Không lặp lại mô tả file đã có, giữ nguyên style hiện tại.
