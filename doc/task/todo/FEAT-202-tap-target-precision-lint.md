---
id: FEAT-202
title: "Nâng rule tap target: kiểm Semantics và kích thước theo từng GestureDetector, không theo file"
type: feature
layer: lib/core/utils/accessibility_audit + tool
priority: P2
effort: M
source: "ENH-106: inventory_grid slot và spotlight skip link thiếu button semantics/48dp mà audit tĩnh không báo"
---

## Vấn đề
Rule `tapTargetSemantics` chỉ đòi file có `Semantics(` ở đâu đó. Một file có Semantics cho phần khác vẫn che được GestureDetector trần (đúng trường hợp spotlight_overlay). Không rule nào kiểm kích thước < 48dp.

## Phạm vi
- Rule mới theo **cửa sổ ngữ cảnh**: với mỗi `GestureDetector(`/`InkWell(`, nhìn ancestor gần (~N dòng hoặc cùng build) có `Semantics(`/`MergeSemantics`/`semanticLabel`; thiếu thì cảnh báo.
- Rule kích thước: phát hiện `width:`/`height:` literal < 48 trên cùng subtree của vùng chạm; chỉ cảnh báo (heuristic tĩnh), kèm `// a11y-ok: <lý do>` để tắt.
- Chấp nhận false negative với kích thước động; ghi rõ giới hạn trong doc rule.

## Đã làm (2026-11-12): pha 1, rule theo vị trí
`AuditRuleId.tapTargetSite`: mỗi `GestureDetector(`/`InkWell(` cần Semantics/MergeSemantics/semanticLabel/ExcludeSemantics trong cửa sổ 8 dòng trước và 30 dòng sau. Thử nghiệm trên repo: rule theo file cũ báo 0 vị trí, rule mới báo 24 vị trí ở 16 file; đã đọc từng vị trí và ghi baseline có lý do (wrapper dùng chung, barrier, debug-only) hoặc trỏ ENH-107 cho lỗi thật. 3 test cho rule; test cũ và fixture CLI cập nhật (cô lập rule bằng `_only`, kỳ vọng hai vi phạm cho một GestureDetector trần).
Giới hạn đã biết: heuristic theo cửa sổ dòng (một wrapper cách xa hơn 30 dòng sẽ bị báo nhầm), và theo file thì mỗi file chỉ hiện một vi phạm dù nhiều vị trí.
- [ ] Pha 2 chưa làm: rule kích thước (`width:`/`height:` literal < 48) với `// a11y-ok:`.

## Tiêu chí xong
- Chạy trên repo: các vi phạm đã ghi ở ENH-106 (toggle_switch 30, segmented_tab_bar 36) xuất hiện; baseline cập nhật.
- Test cho rule: một GestureDetector trần trong file có Semantics khác phải bị báo.

## Pha 2 (2026-11-14): warning-only size heuristic
- [x] Added `AuditRuleId.tapTargetSize`: inspect a narrow local window (4 source lines before, 8 after each `GestureDetector(`/`InkWell(`) for literal `width:`/`height:` below 48 logical pixels.
- [x] Same-line `// a11y-ok: <reason>` suppresses a matching literal only when reason is non-empty.
- [x] Dynamic sizes and dimensions outside the window remain unchecked. This source-text warning does not measure the render tree or effective hit region.
- [x] Repo scan found one real case: EnergyBar refill target was 28×28. Expanded hit box to 48×48 while keeping visible icon unchanged; widget test asserts size.
- [x] Unit tests pass; `dart run tool/accessibility_audit_check.dart` reports no issues; targeted analyzer clean.

## Phụ thuộc
- [x] FEAT-200 phase 2f completed; viewport fixtures cover real widgets for heuristic verification.
