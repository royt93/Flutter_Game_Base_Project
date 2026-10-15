---
id: FEAT-102
title: RewardSequenceCoordinator — State machine điều phối chuỗi nhận thưởng đa tầng
type: feature
priority: P0
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Các màn nhận thưởng thường phải ghép thủ công nhiều widget qua Future.delayed, dễ bị lệch nhịp, chồng chéo hoặc rò rỉ timer khi đóng popup bất ngờ.

## Đề xuất phạm vi
State machine điều phối chuỗi tuần tự: Banner trượt xuống -> Sao nổ nhịp -> Điểm số lăn -> Pháo hoa nổ -> Nút Continue nảy. Hỗ trợ skip toàn bộ chuỗi khi người chơi chạm màn hình.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [x] **Unit test**: Kiểm tra chuyển đổi trạng thái tuần tự từ Banner -> Stars -> Counter -> Confetti -> Ready và hàm skipToReady.
- [x] **Widget test**: Pump qua từng giai đoạn của chuỗi, kiểm tra các widget con hiển thị đúng thời điểm; huỷ widget giữa chừng không để lại timer rò rỉ.
- [x] **Integration test**: Kích hoạt chuỗi ăn mừng chiến thắng trên thiết bị thật, kiểm tra độ mượt và phản hồi nút bấm.

## Yêu cầu hiệu năng & Animation
- [x] **60 FPS & Resource cleanup**: Mỗi step kích hoạt độc lập, tự động hủy bỏ listener và animation controller khi dispose.
