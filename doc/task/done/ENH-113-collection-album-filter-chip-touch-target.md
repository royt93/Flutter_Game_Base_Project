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

- Phát hiện khi làm: KHÔNG thể mở rộng vùng chạm mà giữ nguyên chiều cao. Thử đo trực tiếp: một con `GestureDetector` tràn ra ngoài layout box của cha (Stack, `clipBehavior: Clip.none`, `top/bottom: -5.5`) không nhận tap ngoài box (cả hai điểm thử đều 0 tap). Nên cách "đệm vô hình" ghi trong phạm vi ban đầu không khả thi; chip phải cao thật.
- Sửa: bọc chip trong `ConstrainedBox(minHeight: 44)` + `Align(widthFactor: 1, heightFactor: 1)`, `behavior: opaque`. Đo thật: chip 62.8x44, 87.3x44, 111.8x44 (trước: 33 cao); panel 380 -> 391 (+11dp). Diff thật: 10 dòng thêm.
- Test: 1 test mới (3 chip >= 44dp cao, nhãn "<Tên> filter" không đổi); mutation `minHeight: 30` làm test đỏ. Root 4127 pass, example 472 pass, analyze, audit a11y, API gate sạch.
- Golden: ước tính ban đầu 28 ảnh nhưng đo thật chỉ **12 ảnh** đổi pixel (`collectionalbumpanel_complete_reward_*` và `_mixed_rarity_*`, mỗi bộ 6 biến thể; lệch 5.7% đến 8.6%, cùng kích thước 800x600). 16 ảnh còn lại (các trạng thái không có chip hiển thị trong khung) không đổi. Tạo lại qua workflow `regenerate-goldens.yml` (run `45148311547`, commit nguồn `e0ab5a32`), chỉ copy 12 PNG đó. Artifact còn khác 655 file ở mức byte nhưng 0.000% pixel (chỉ mã hoá PNG), không import. So sánh trực quan: chip nhìn y hệt, khoảng cách quanh chip rộng hơn nên panel dịch vài px, không có lỗi render.
- Ghi chú ENH-112: golden `eventcalendarcard_week_schedule_*` (7 ảnh) đã được CI Linux xác nhận xanh (run `45146483936`, cả 3 job success).
- Audit / điểm: ~9.1/10. Trừ điểm: cách "đệm vô hình" của phạm vi ban đầu không khả thi nên panel cao hơn 11dp; chưa kiểm bằng TalkBack/ngón tay thật.
- Commit/push: `e0ab5a32` (sửa), golden ở commit kế tiếp.
