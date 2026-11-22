---
id: IDEA-93
title: "Capability & Evidence Matrix — phân biệt logic local, adapter và behavior đã xác minh"
type: idea
layer: docs/quality
priority: P2
effort: M
source: "Full source audit 2026-11-21; release checklist warns against inferring backend behavior from UI wiring"
---

## Ý tưởng

Tạo một matrix có thể cập nhật, ánh xạ các capability nổi bật của SDK sang loại implementation (local logic, adapter seam, demo wiring, backend/device verified), evidence hiện có (tests/docs/device run), và điều gì chưa được chứng minh. Dùng làm “evidence-backed SDK” trust differentiator thay vì marketing claim chung.

## Giá trị

Partner biết chính xác package tự làm gì, chỗ nào cần adapter/backend, và proof nào hỗ trợ từng claim. Giảm nhầm UI/callback demo là production delivery/payout/analytics.

## Phạm vi đề xuất

- Chọn nhóm capability public/high-value trước, không liệt kê mọi class.
- Link tới test/task/evidence hiện có; không tạo proof giả hoặc claim từ UI screenshot.
- Cập nhật cùng release checklist/docs process hoặc ghi rõ owner/cadence.
- Đây là docs/positioning idea, không đổi API/runtime.

## Acceptance criteria

- [ ] Mỗi dòng phân loại capability và nêu bằng chứng/giới hạn rõ.
- [ ] Claims được cross-check với code, tests và release checklist; backend behavior chỉ ghi verified khi có backend evidence.
- [ ] Không trùng `IDEA-90` consumer integration doctor hoặc release intake checklist.
- [ ] Docs/link tests phù hợp; unit/widget/integration không áp dụng vì docs-only (ghi lý do).
- [ ] Audit claims và chấm >9/10 (accuracy 5, usefulness 2, maintainability 2, checks 1).
- [ ] Không cần device smoke trừ khi claim mới phụ thuộc thiết bị; nếu cần, physical device và evidence rõ, không simulator.

## Prompt loop

Đọc README, public API, demo seams, test map, QA matrix và release checklist. Chọn ít capability đủ đại diện; với mỗi claim lần ngược đến implementation/evidence. Đánh dấu `local`, `seam`, `demo`, `backend/device verified`, hoặc `not verified`, và viết explicit non-goals. Không phát minh bằng chứng hay biến đây thành catalogue toàn repo. Chạy link/markdown checks, audit claim từng dòng và chấm /10 theo rubric; lặp đến >9/10. Dừng nếu không thể xác minh claim, source-of-truth/maintenance owner chưa rõ, hoặc có overlap; hỏi owner trước khi mở rộng. Khi acceptance đạt, ghi kết quả và push docs theo yêu cầu owner nếu score >9/10.

## Kết quả thực hiện

- Capabilities covered:
- Audit / điểm:
- Checks:
- Device evidence (nếu cần):
- Commit/push:
