# Backlog audit 2026-09-12

## Phạm vi và baseline

- Đã inventory toàn bộ `lib/` (10,064 dòng), `example/lib/`, 13,210 dòng test, shader, pubspec/config/CI và toàn bộ task trong `todo/inprogress/done`.
- Giữ nguyên worktree dở dang của IDEA-38 và các sửa đổi theme/translations/storage.
- Root `flutter analyze` sạch; root và example test pass ở snapshot audit. `dart pub publish --dry-run` có 2 warning và đang đóng gói tài liệu backlog nội bộ.
- Independent review: đã gọi `codex --yolo`, `agy --dangerously-skip-permissions`, `claude --dangerously-skip-permissions`. Claude CLI hết weekly quota; raw opinions cũ của agy/Claude vẫn được dùng như nguồn tham khảo, mọi finding được kiểm tra lại trên source hiện tại trước khi đưa vào task.

## Thứ tự Scrum đề xuất

1. P0: BUG-34, ENH-56.
2. P1: BUG-35, BUG-36, ENH-57, ENH-58 và hoàn tất IDEA-38 đang inprogress.
3. Quality debt đã có: ENH-36/37/38/39/54/55.
4. Product foundation: FEAT-31, sau đó quyết định hợp nhất/ranh giới với IDEA-33.
5. Exclusive discovery: IDEA-40 trước, IDEA-41 và IDEA-42 sau; chỉ commit full build sau prototype đạt tiêu chí go/no-go.

## Các phương án để owner chọn

| Option | Nội dung | Ưu điểm | Nhược điểm |
|---|---|---|---|
| A — Reliability & publish readiness (khuyến nghị) | BUG-34/35/36 → ENH-56/57/58 → quality debt | Giảm crash/corrupt, tạo API package đúng chuẩn, mở đường pub.dev | Killer feature xuất hiện muộn hơn |
| B — Product-first | Hoàn tất IDEA-38 → FEAT-31 → IDEA-40 prototype, xen kẽ P0 | Có demo khác biệt và value người dùng sớm | Nợ package/recovery còn tồn tại lâu hơn |
| C — Exclusive bet | Spike IDEA-40 + IDEA-42 trước, chỉ fix BUG-34 song song | Kiểm chứng lợi thế cạnh tranh sớm | Rủi ro effort L và nền public API chưa ổn định |

Khuyến nghị Option A vì repo đã có nhiều tính năng nhưng chưa có root entrypoint và còn ba đường crash/corrupt cụ thể; ổn định nền trước giúp mọi feature sau có API/test/release gate đáng tin hơn.

## Definition of Done dùng chung

Mỗi task là một file riêng. Loop chỉ kết thúc khi agent tự audit changes và đạt >9/10, có unit + widget + integration test cho mọi case, analyze/test root và example sạch, smoke test trên Android device thật có bằng chứng, rồi mới commit + push. Sau push phải cập nhật quyết định/checkbox, chuyển file sang `done`, commit + push lần hai.
