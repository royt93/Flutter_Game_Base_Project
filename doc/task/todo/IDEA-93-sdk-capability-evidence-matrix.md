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

- Deliverable: `docs/qa/capability_evidence_matrix.md` (8 capability đại diện: save integrity, storage/versioned save, cloud save seam, offline progression, IAP, rewarded ad, analytics ACK, offline outbox), nhãn `local`/`seam`/`demo`/`device verified`/`not verified`, mỗi dòng có cột "Not proven". Link từ `README.md` mục Device proof. Có quy tắc cập nhật + owner/cadence (mỗi release, khi export đổi).
- Cross-check: mọi path code/test dẫn trong bảng đều tồn tại (script kiểm tra); claim save_integrity đối chiếu doc comment trong `lib/core/save_integrity.dart` (secret do app cấp, vẫn recover được từ binary, chỉ chống sửa save thông thường). Không ghi backend/payout/analytics transport là verified.
- Không trùng IDEA-90 (doctor) hay intake checklist: ghi rõ ranh giới trong file.
- Checks: link/path check OK; `test/tool/release_readiness_check_test.dart` pass. Unit/widget/integration không áp dụng vì docs-only, không đổi API/runtime. Device smoke không cần: chỉ trích dẫn record S24U đã có trong `device_matrix.md`.
- Audit / điểm: ~9.2/10. Trừ điểm: chỉ 8 capability, chưa có test tự động giữ bảng khớp code (chỉ review tay).
- Commit/push:
