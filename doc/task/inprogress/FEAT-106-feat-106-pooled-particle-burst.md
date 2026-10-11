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

## Yêu cầu kiểm thử
- [x] **Unit/widget test**: Radial geometry/fade timing; 50 pooled particle instances được prewarm/release/reuse qua 10 bursts, Reduced Motion, unmount mid-burst.
- [x] **Showcase test**: Button chạy 3 chu kỳ; `totalCreated` giữ nguyên 50 và pool trả đủ free items.
- [x] **TECNO integration smoke**: Chạy 10 bursts 50 particles trên TECNO KJ7; active count về 0, totalCreated vẫn 50.
- [x] **Host validation**: targeted tests/analyzers pass.

## Hiệu năng & lifecycle
- [x] Pool được prewarm, particle objects reset/reuse, ticker dừng và release ngay sau thời lượng.
- [ ] 60 FPS/GC benchmark: chưa có workload benchmark/heap allocation profile riêng; không tuyên bố zero-GC hoặc sustained 60 FPS.
