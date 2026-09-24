---
id: ENH-93
title: "CLAUDE.md's Commands section thiếu 5 lệnh quality-gate CI thật đang chạy"
type: enhancement
priority: P4
effort: XS
source: "claude (fork audit round 2, độc lập)"
---

## Vị trí
`CLAUDE.md`'s `## Commands` section, đối chiếu với
`.github/workflows/ci.yml`'s job `quality-gate` (dòng 66-80).

## Hiện trạng
`.github/workflows/ci.yml`'s job `quality-gate` chạy 5 lệnh CI thật (chạy
CÓ ĐIỀU KIỆN qua `paths-filter`, nên dễ bị bỏ sót khi đọc lướt workflow
file):
- `dart run tool/accessibility_audit_check.dart`
- `dart run tool/dependency_sbom_check.dart --suppressions=...`
- `dart run tool/asset_license_check.dart`
- `dart run tool/performance_budget_check.dart check`
- `dart run tool/deprecation_check.dart`

Không lệnh nào trong 5 lệnh này xuất hiện trong CLAUDE.md's `## Commands`
section — section đó chỉ liệt kê `flutter analyze`/`flutter test`/
`api_compatibility`/`dart pub publish --dry-run`.

## Vì sao cần / Hậu quả
Người/AI làm việc theo đúng CLAUDE.md để biết "cần chạy gì trước khi push"
sẽ hoàn toàn không biết 5 gate này tồn tại cho tới khi CI fail trên 1 PR có
đụng đúng path kích hoạt (`lib/`/`tool/`/dependency file liên quan) —
lãng phí 1 vòng CI fail + fix thay vì phát hiện sớm ở local.

## Đề xuất
Thêm 1 đoạn ngắn vào CLAUDE.md's `## Commands` section liệt kê đúng 5 lệnh
trên (kèm chú thích ngắn "chạy có điều kiện qua paths-filter trong CI, xem
`.github/workflows/ci.yml` job `quality-gate`" để không đánh lừa là luôn
chạy mọi PR).

## Acceptance criteria
- [x] Cả 5 lệnh quality-gate xuất hiện trong CLAUDE.md's Commands section,
      đúng cú pháp/flag như trong `ci.yml` (copy chính xác, không gõ lại
      từ trí nhớ).
- [x] Có ghi chú rõ đây là gate CHẠY CÓ ĐIỀU KIỆN (paths-filter), không
      phải luôn chạy mọi lần push — tránh gây hiểu lầm ngược lại.
- [x] Không đổi bất kỳ nội dung nào khác của CLAUDE.md ngoài đoạn thêm này
      (đây là task chỉnh doc, phạm vi tối thiểu).

## Quyết định

**Implementation**: thêm 2 đoạn vào `CLAUDE.md`:
1. Trong code block `## Commands`, thêm 1 nhóm lệnh mới ngay sau
   `dart pub publish --dry-run`, comment đầu nhóm ghi rõ "only runs when
   lib/, tool/, or pubspec.yaml changed" — copy nguyên văn cả 5 lệnh từ
   `.github/workflows/ci.yml` dòng 68-80 (kể cả flag
   `--suppressions=tool/dependency_sbom_suppressions.json` và subcommand
   `check` của `performance_budget_check.dart`).
2. Trong đoạn văn xuôi mô tả CI ngay dưới code block, thêm 1 câu giải thích
   job `quality-gate` là job RIÊNG (không phải phần của `analyze-test`),
   chạy có điều kiện qua `paths-filter`, và dễ bị bỏ sót vì lý do đó.

Tự verify bằng cách `grep` lại cả 2 file (`ci.yml` và `CLAUDE.md`) đối
chiếu 1-1 sau khi viết — xác nhận khớp chính xác, không có lệnh nào bị gõ
sai/thiếu flag.

**Kết quả**: chỉ sửa `CLAUDE.md`, không đụng code — không cần
`flutter analyze`/`flutter test`. Đã đối chiếu lại `.github/workflows/ci.yml`
1 lần nữa SAU KHI viết xong để xác nhận đúng 100%.

**Tự chấm điểm: 9.5/10.** Đúng phạm vi tối thiểu (chỉ thêm, không sửa nội
dung khác), nội dung chính xác 1-1 với CI thật, có giải thích rõ tính chất
"chạy có điều kiện" để không gây hiểu lầm ngược. Trừ 0.5 vì không thể tự
động hoá việc "giữ đồng bộ mãi mãi" — nếu `ci.yml` đổi lệnh trong tương lai,
CLAUDE.md sẽ lại lệch, không có gate nào tự phát hiện việc này (ngoài audit
thủ công như task này).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-93-claude-md-missing-ci-quality-gate-commands.md`
này trước khi làm. Đọc TOÀN BỘ `.github/workflows/ci.yml` (không chỉ đoạn
dòng 66-80 đã trích) để hiểu đúng điều kiện `paths-filter` kích hoạt job
`quality-gate`, rồi đọc `CLAUDE.md`'s `## Commands` section hiện tại trước
khi sửa. Đây là task sửa DOC, không sửa code — không cần TDD, không cần
chạy `flutter test`. Chỉ cần đảm bảo nội dung thêm vào chính xác 1-1 với
`ci.yml` thật (copy lệnh, không tự bịa flag).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại nội dung vừa viết, chấm điểm /10 — kiểm tra lại từng lệnh
   đã copy đúng 1-1 với `ci.yml` chưa (đọc lại `ci.yml` lần nữa để đối
   chiếu, không tin vào trí nhớ).
2. Không cần chạy `flutter analyze`/`flutter test` (task chỉ sửa file .md).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — fork audit đã đọc trực tiếp cả `.github/workflows/ci.yml` lẫn
CLAUDE.md, đối chiếu 1-1 xác nhận đúng 5 lệnh thiếu. Rủi ro thấp (chỉ sửa
doc, không sửa code), effort nhỏ nhất trong 6 task. Không trùng task nào
trong `doc/task/done/`.
