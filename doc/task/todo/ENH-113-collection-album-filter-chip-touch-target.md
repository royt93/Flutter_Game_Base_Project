---
id: ENH-113
title: "CollectionAlbumPanel: chip lọc cao 33dp, dưới vùng chạm tối thiểu 44dp"
type: enhancement
layer: lib/presentation/widgets/common
priority: P3
effort: S
source: "ENH-112 (2026-11-23): quét semantics tự động trên 339 case sweep; đã đọc source và đo trực tiếp"
---

## Bằng chứng đã đo

- `CollectionAlbumPanel._filterChip` dựng chip bằng `GestureDetector` + `Container` với `padding: symmetric(horizontal: 12, vertical: 7)`, không có vùng chạm tối thiểu.
- Đo thật (viewport 400x900, 1 item): chip `all` 62.8x33.0, `owned` 87.3x33.0, `missing` 111.8x33.0 (cao 33dp, dưới 44dp).
- Nhãn thì ổn: `Semantics(button: true, selected: selected, label: '$label filter')`.
- So sánh trong cùng file: nút `collectionViewRewardBtn` đã có `ConstrainedBox(minWidth: 48, minHeight: 48)`; chip lọc thì chưa.

## Phạm vi

- Nâng vùng chạm của 3 chip lên tối thiểu 44dp chiều cao mà KHÔNG nhất thiết đổi hình dạng chip: bọc vùng chạm trong `ConstrainedBox(minHeight: 44)` + `Align`, giữ chip nhìn 33dp bên trong. Cách này không đổi ảnh golden nếu vùng đệm trong suốt và bố cục cha không đổi chiều cao (cần kiểm: `Wrap` sẽ tăng chiều cao hàng).
- Nếu chiều cao hàng tăng, golden `collectionalbumpanel_*` (28 ảnh) đổi và phải sinh lại bằng workflow `regenerate-goldens.yml` (chỉ copy đúng các PNG đổi, không copy cả artifact; golden không bao giờ sinh từ macOS).

## Lưu ý từ ENH-112 (đọc trước khi làm)

- `MergeSemantics` bọc ngoài `Semantics` làm mất nhãn tường minh; đừng thêm nếu không cần. Lỗi nhãn của `ExpandablePanel` do hai node cùng khai báo tap, không do thiếu merge.
- `constraints` trên `IconButton` không thắng `visualDensity: compact`; với `GestureDetector` thì `ConstrainedBox` có tác dụng (như `collectionViewRewardBtn`).

## Acceptance criteria

- [ ] Test đo kích thước thật của 3 chip >= 44dp chiều cao, và test nhãn/selected không đổi.
- [ ] Mutation: bỏ ràng buộc thì test đỏ.
- [ ] Nếu golden đổi: sinh lại qua workflow, ghi rõ số PNG đổi; nếu không đổi: ghi bằng chứng (ảnh golden pass trên Linux).
- [ ] Không đổi API công khai; CHANGELOG mục accessibility cập nhật.
- [ ] Audit >9/10.

## Kết quả thực hiện

- Audit / điểm:
- Tests:
- Golden:
- Commit/push:
