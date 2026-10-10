---
id: FEAT-106
title: PooledParticleBurst — Hệ thống hạt nổ tối ưu Zero-GC tích hợp ObjectPool
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Khi nổ hũ/ăn điểm lớn cần 50-100 hạt sao/kim cương tung bay; tạo mới hàng trăm object particle gây áp lực Garbage Collection dẫn tới tụt khung hình.

## Đề xuất phạm vi
Widget PooledParticleBurst quản lý hạt bằng ObjectPool<Particle> tái sử dụng bộ nhớ hạt cũ, vẽ hàng loạt trên 1 CustomPainter duy nhất.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Chứng minh 0 object particle mới được cấp phát trong chu kỳ nổ hạt thứ 2 trở đi thông qua ObjectPool.
- [ ] **Widget test**: Kích hoạt nổ 50 hạt, kiểm tra hạt bay ra từ tâm và tự thu hồi về pool sau khi hết tuổi thọ.
- [ ] **Integration test**: Spam nút nổ hạt 10 lần liên tục trên thiết bị thật, kiểm tra FPS không bị giật và bộ nhớ ổn định.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Tận dụng ObjectPool đã có kiểm chứng 97.5% allocation reduction trong kit.
