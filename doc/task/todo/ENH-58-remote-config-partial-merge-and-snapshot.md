---
id: ENH-58
title: "RemoteConfig giữ asset fallback khi remote response chỉ có một phần key"
type: enhancement
priority: P1
effort: M
source: Codex audit 2026-09-12
depends_on: []
---

## User story
Là live-ops developer, tôi muốn remote payload chỉ override key được gửi và các key khác vẫn dùng asset fallback đã kiểm thử.

## Hiện trạng và bằng chứng
`RemoteConfigService.init()` load asset vào `_config`, sau đó gán toàn bộ `_config = await fetch()` tại `lib/core/remote_config_service.dart:35-51`. Một remote response hợp lệ nhưng partial làm mất tất cả fallback key còn lại. Service cũng không expose snapshot bất biến để debug/test khác biệt asset/remote.

## Scope
- Merge asset defaults với remote overrides theo key, với policy rõ cho `null` và type mismatch.
- Expose snapshot read-only và source/status tối thiểu; không kéo HTTP/Firebase SDK.
- Giữ init failure không chặn boot và làm nền cho IDEA-37.

## Acceptance criteria
- [ ] Partial remote override không xóa fallback key không có trong response.
- [ ] Response rỗng, throw, null/sai type có policy xác định và không corrupt snapshot tốt gần nhất.
- [ ] Snapshot không thể bị caller mutate ngược vào service.
- [ ] Unit, widget, integration và device smoke test bao phủ asset-only, partial/full remote, error và retry.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy analyze/test root + example; smoke test Android device thật và lưu bằng chứng. Nếu chưa đạt >9/10 thì lặp tiếp. Chỉ khi work đúng và điểm >9/10 mới commit + push; sau push cập nhật Quyết định, chuyển task sang done, commit + push lần hai.

