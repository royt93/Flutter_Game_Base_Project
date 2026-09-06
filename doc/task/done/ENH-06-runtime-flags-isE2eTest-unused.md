---
id: ENH-06
title: "RuntimeFlags.isE2eTest được định nghĩa nhưng không nơi nào dùng"
type: enhance
priority: P2
effort: S
source: Claude-CLI, verify lại code thật (grep toàn repo)
---

## Hiện trạng
`lib/core/runtime_flags.dart:5` định nghĩa `isE2eTest` (đọc
`--dart-define=E2E_TEST=true`). CLAUDE.md mô tả nó dùng để "skip audio init
during automated device tests". Nhưng grep toàn repo: không có callsite nào
trong `lib/` hay `example/lib/` tham chiếu tới nó.
`example/integration_test/app_boot_test.dart` tự truyền cứng `withAudio: false`
thay vì dựa vào flag này — tài liệu và code đang lệch nhau.

## Đề xuất
Chọn 1 trong 2:
1. Wire thật: `example/lib/main.dart` đọc `isE2eTest` để tự quyết
   `withAudio: false`, bỏ tham số `withAudio` thủ công ở test.
2. Nếu cờ này không còn cần thiết, xoá khỏi export public + cập nhật CLAUDE.md.

## Acceptance criteria
- [ ] Code và mô tả trong CLAUDE.md khớp nhau về việc `isE2eTest` có được dùng hay không.
