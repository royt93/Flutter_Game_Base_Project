---
id: BUG-100
title: "Release gate sweep"
type: bug
priority: P2
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

(a) `.github/workflows/ci.yml:64-65,70-71` sbom chỉ root; (b) `example/integration_test/app_boot_test.dart` không có route GameDemo; (c) `test/widget/goldens/golden_test_support.dart:19` tolerance 1%.

## Hiện trạng

(a) `flutter pub get` + sbom job chỉ chạy trong `quality-gate` (paths-filter `lib/**,tool/**,pubspec.yaml`), không có bước tương ứng cho `example/pubspec.yaml` — graph dependency riêng của example không được audit. (b) `app_boot_test.dart` chỉ có test đi tới `WidgetShowcaseScreen`/`CookbookScreen`, không có test route Home→GameDemo→tap circle→HUD đổi→Pause/Resume. (c) `_maxDiffPercent = 0.01` (1%) — ở golden 1080x2400 tương đương ~25920px sai lệch được chấp nhận, có thể che regression thật.

## Vì sao cần / Hậu quả

Gap giữa "CI xanh" và thực tế: dependency example không audit an ninh, core gameplay loop chưa có device smoke test, golden tolerance rộng che regression nhỏ-vừa.

## Đề xuất

(a) chạy `dependency_sbom_check` cho example lockfile riêng; (b) thêm integration test Home→GameDemo→tap→HUD→Pause/Resume; (c) fixture chứng minh 1.00% pass/1.01% fail + document policy chọn ngưỡng.

## Acceptance criteria

- [ ] SBOM check chạy và fail được khi example thêm dependency có suppression thiếu.
- [ ] Integration test mới cho GameDemo pass trên device.
- [ ] Golden tolerance fixture chứng minh biên chính xác 1.00%/1.01%.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify ci.yml dòng 69-71 sbom step chỉ trong `quality-gate` root context, `app_boot_test.dart` không có GameDemo navigation helper, `golden_test_support.dart` dòng 19 `_maxDiffPercent = 0.01`.
