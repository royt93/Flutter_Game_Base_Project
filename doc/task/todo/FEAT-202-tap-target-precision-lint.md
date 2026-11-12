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

## Tiêu chí xong
- Chạy trên repo: các vi phạm đã ghi ở ENH-106 (toggle_switch 30, segmented_tab_bar 36) xuất hiện; baseline cập nhật.
- Test cho rule: một GestureDetector trần trong file có Semantics khác phải bị báo.

## Phụ thuộc
Nên làm sau FEAT-200 để có widget test thật bổ sung cho phần heuristic.
