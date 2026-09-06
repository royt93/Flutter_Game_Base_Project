---
id: IDEA-01
title: "Offline Earnings Engine — điểm bán độc quyền dựa trên ClampedClock"
type: idea
priority: exclusive
effort: L
source: agy + claude-CLI (cùng đề xuất, đóng khung lại thành 1 differentiator)
---

## Ý tưởng
`ClampedClock` (`lib/core/utils/clamped_clock.dart`) đã giải quyết đúng bài
toán khó nhất của idle game: chống gian lận bằng cách tua lùi đồng hồ máy —
hiếm base kit nào trên pub.dev có sẵn cơ chế này. Thay vì chỉ dùng nó âm thầm
cho reward system nội bộ, đóng gói FEAT-09 (Offline Progression Calculator)
thành 1 module gắn nhãn rõ ràng "Cheat-proof Offline Earnings" — biến 1 chi
tiết kỹ thuật đã có sẵn thành lý do khách hàng chọn kit này thay vì kit khác.

## Vì sao khác biệt
Phần lớn kit/game-template khác tính offline earnings dựa thẳng vào
`DateTime.now()` — dễ bị cheat bằng cách chỉnh giờ hệ thống. Kit này đã có sẵn
lớp bảo vệ, chỉ cần đóng gói + tài liệu hoá đúng cách để trở thành điểm bán.

## Phụ thuộc
Cần hoàn thành FEAT-09 trước.
