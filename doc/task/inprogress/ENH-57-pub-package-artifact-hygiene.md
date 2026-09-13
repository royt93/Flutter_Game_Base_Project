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
- [ ] Artifact không chứa backlog, AI raw opinions, IDE/local metadata hay kế hoạch nội bộ.
- [ ] Asset runtime, public Dart API, README, license và example cần thiết vẫn có trong archive.
- [ ] `dart pub publish --dry-run` sạch warning thuộc quyền kiểm soát repo; package size được ghi nhận trước/sau.
- [ ] Unit, widget, integration và device smoke test xác nhận package consumer vẫn hoạt động.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng test-first cho package contents. Kết thúc mỗi vòng phải: audit lại changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy analyze/test root + example, `dart pub publish --dry-run`, và smoke test Android device thật có bằng chứng. Nếu chưa đạt >9/10 thì lặp tiếp. Chỉ khi work đúng và điểm >9/10 mới commit + push; sau push cập nhật Quyết định, chuyển task sang done, commit + push lần hai.

