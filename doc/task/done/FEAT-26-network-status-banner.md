---
id: FEAT-26
title: NetworkStatusBanner — banner báo offline/online
type: feature
priority: P1
effort: S
source: user pick (vòng đề xuất thêm widget, chốt)
---

## Vì sao cần
FEAT-16 (Cloud save, đang P0) sẽ fail âm thầm nếu mất mạng mà không ai báo
người chơi — banner này là điều kiện cần để FEAT-16 không gây trải nghiệm
khó hiểu ("sao progress không lưu?").

## Đề xuất phạm vi
`NetworkStatusBanner`: widget hiển thị dải banner mỏng trên cùng màn hình khi
`connected == false` (nhận vào từ ngoài qua `bool`/`Stream<bool>`, KHÔNG tự
gọi `connectivity_plus` hay package mạng nào — giữ package gốc không thêm
dependency mới, app tự quyết định nguồn tín hiệu mạng và truyền vào).

## Yêu cầu test
- **Unit test**: không áp dụng (thuần trình bày theo input).
- **Widget test**: truyền `connected: false` → banner hiện; `true` → ẩn (hoặc animate ẩn), verify không giữ lại `AnimationController` sau khi ẩn hẳn.
- **Integration test**: demo trong `example/integration_test/` toggle trạng thái giả lập, verify banner ẩn/hiện đúng trên thiết bị thật.

## Demo
Section "Network Banner" trong `WidgetShowcaseScreen` với toggle giả lập online/offline.

## Acceptance criteria
- [ ] Không kéo thêm dependency mạng nào vào `pubspec.yaml` — chỉ nhận state từ ngoài.
- [ ] Đủ 3 loại test + demo.
