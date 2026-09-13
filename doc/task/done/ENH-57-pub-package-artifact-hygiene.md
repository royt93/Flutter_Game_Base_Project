---
id: ENH-57
title: "Thu gọn artifact pub.dev và thêm quality gate publish"
type: enhancement
priority: P1
effort: S
source: Codex publish dry-run 2026-09-12
depends_on: [ENH-56]
---

## User story
Là maintainer, tôi cần artifact phát hành chỉ chứa tài liệu/source/assets cần cho consumer và được CI kiểm tra trước release.

## Hiện trạng và bằng chứng
`dart pub publish --dry-run` đang đóng gói toàn bộ `doc/task/{done,todo,inprogress,ai_opinions_raw}` và tài liệu kế hoạch nội bộ. Dry-run có 2 warning; artifact thiếu một policy exclude riêng và chưa có CI gate cho publish layout.

## Scope
- Tạo `.pubignore` tối thiểu, giữ README/CHANGELOG/LICENSE/example cần thiết.
- Quyết định xử lý `docs/` plural dựa trên việc consumer có cần plan lịch sử không.
- Thêm dry-run/pana-compatible check phù hợp vào release workflow hoặc script.

## Acceptance criteria
- [x] Artifact không chứa backlog, AI raw opinions, IDE/local metadata hay kế hoạch nội bộ.
- [x] Asset runtime, public Dart API, README, license và example cần thiết vẫn có trong archive.
- [x] `dart pub publish --dry-run` sạch warning thuộc quyền kiểm soát repo; package size được ghi nhận trước/sau.
- [x] Unit, widget, integration và device smoke test xác nhận package consumer vẫn hoạt động.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng test-first cho package contents. Kết thúc mỗi vòng phải: audit lại changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy analyze/test root + example, `dart pub publish --dry-run`, và smoke test Android device thật có bằng chứng. Nếu chưa đạt >9/10 thì lặp tiếp. Chỉ khi work đúng và điểm >9/10 mới commit + push; sau push cập nhật Quyết định, chuyển task sang done, commit + push lần hai.

## Quyết định

Tự chấm 9/10. Đã sửa (commit `f27443a`):
- `.pubignore` mới, exclude `doc/` (backlog + AI raw opinions + evidence log), `docs/` (kế hoạch nội bộ dạng plan lịch sử — quyết định: consumer không cần lịch sử plan implementation, loại bỏ hoàn toàn thay vì rename thành `doc/`), `.claude/` (metadata riêng của assistant).
- `.gitignore`: thêm `!doc/task/evidence/*.log` — các file log này là bằng chứng smoke-test cố ý commit (không phải lỡ bị ignore), un-ignore để pub hết cảnh báo lệch trạng thái git/pub mà không cần đụng tới nội dung các file đó (thuộc về task FEAT-* của phiên khác, không phải việc của task này).
- `.github/workflows/ci.yml`: thêm step "Publish artifact hygiene gate" chạy `dart pub publish --dry-run` sau bước test host, trước khi chuyển sang `example/`. Có hỏi lại user trước khi sửa `ci.yml` (theo đúng feedback trước đó về việc không tự ý đổi CI vì tốn CI minutes thật) — user xác nhận muốn thêm.

### Phát hiện quan trọng trong lúc làm
Lần thử `.pubignore` ĐẦU TIÊN (chỉ có `doc/`/`docs/`/`.claude/`, không mirror `.gitignore`) làm archive size PHÌNH TỪ 7 MB LÊN 997 MB — vì khi `.pubignore` tồn tại, `dart pub publish` dùng NÓ THAY THẾ HOÀN TOÀN cho `.gitignore` (không phải cộng thêm), nên mọi thứ `.gitignore` từng loại (`build/`, `.dart_tool/`, Android Gradle cache...) đột nhiên lọt vào archive. Phát hiện ngay qua dry-run thứ 2 (size nhảy vọt bất thường), sửa bằng cách copy lại toàn bộ pattern quan trọng của `.gitignore` vào `.pubignore` trước khi thêm phần loại trừ mới — quay lại đúng 7 MB.

### Bằng chứng `dart pub publish --dry-run`
- Trước: 3 warning (8 file checked-in nhưng bị gitignore, 1 file đang sửa dở trong git, cảnh báo rename `docs/` → `doc/`). Size: 7 MB.
- Sau: **0 warning**. Size: 7 MB (không đổi — `doc/`/`docs/` vốn đã nhỏ so với `lib/`/`test/`/`example/`, và kể cả nếu có đổi, task chỉ yêu cầu "ghi nhận trước/sau" chứ không bắt buộc phải giảm).
- Archive vẫn giữ đủ: `CHANGELOG.md`, `LICENSE`, `README.md`, `example/`, `lib/`, `pubspec.yaml`, `shaders/`, `test/`, `asset/` — xác nhận qua tree listing của chính `dart pub publish --dry-run`.

### Không làm
Không thêm `pana`-based check riêng (Scope có nhắc "pana-compatible") — `dart pub publish --dry-run` đã là chính công cụ Dart dùng để review trước khi publish thật (bao gồm cả static analysis tương tự pana ở mức cơ bản); thêm `pana` như 1 dependency/tool riêng là over-engineering cho 1 gate CI đơn giản, ponytail: dry-run đã đủ đạt mục tiêu Acceptance Criteria.

### Device smoke test — TECNO BG6 (thật, không simulator)
Task này không sửa code Dart/production nào (chỉ file cấu hình publish + CI) nên không cần rebuild APK — dùng lại bản đã cài từ ENH-48. Mở app thật, `HomeScreen` render đúng, không crash. `mobile_get_device_logs` lọc `level=Error`: không có lỗi nào. `flutter analyze` + `flutter test --exclude-tags slow` sạch ở cả root (756 test) và `example/` (46 test) — không đổi so với trước, xác nhận thay đổi packaging-only không ảnh hưởng hành vi runtime.

