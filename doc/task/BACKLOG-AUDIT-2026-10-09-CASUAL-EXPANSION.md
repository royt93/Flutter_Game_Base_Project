# Backlog Audit & Sprint Roadmap: Casual Game & App Master Suite (2026-10-09)

## 1. Bối cảnh & Mục tiêu
- Đối tác tiêu thụ SDK yêu cầu tiêu chuẩn gắt gao về:
  1. **Tính năng phong phú**: Mục tiêu là bổ sung các cơ chế casual kinh điển theo nhu cầu partner (Battle Pass, Mystery Chest, Piggy Bank, Scratch Card, v.v.); backlog chưa có nghĩa là các tính năng này đã triển khai.
  2. **Animation tích hợp sẵn ở widget**: Mục tiêu là chuyển động nhất quán, tôn trọng `reducedMotion`; mỗi task phải ghi rõ hành vi đã implement và test.
  3. **Hiệu năng cao**: Mục tiêu đo frame-time/jank và cấp phát dưới workload định nghĩa, trên TECNO KJ7 trước khi tuyên bố 60 FPS hoặc zero-allocation. Chưa có baseline chung cho các widget mới.
  4. **Kiểm thử 3 lớp theo phạm vi**: Unit test (toán/logic/state), Widget test (vòng đời/render/gestures/reduced-motion), Integration test trên thiết bị thật cho luồng quan trọng. Không khẳng định mọi case đều cần chạy qua cả ba lớp nếu test không phù hợp; mỗi task nêu rõ lớp nào bắt buộc và vì sao.

## 2. Danh sách 28 Tasks đã rã vào `doc/task/todo/`

### Wave 1: Core Motion, Performance & Juice System (Nền tảng chuyển động)
| ID | Tiêu đề | Loại | Priority | Effort |
|---|---|---|---|---|
| ENH-97 | Motion Tokens tập trung trong NeonTheme (Duration, Curve, reducedMotion) | Enhancement | P0 | S |
| FEAT-100 | ItemFlyOverlay — bay vật phẩm/icon đa năng từ toạ độ bất kỳ vào HUD/Slot | Feature | P0 | M |
| ENH-98 | Continuous / Responsive CurrencyCounter — lăn số gia tốc mượt khi nhận chuỗi thưởng | Enhancement | P1 | M |
| FEAT-101 | AnimatedInventoryGrid — hiệu ứng hoán đổi vị trí và pop-in item mềm mại | Feature | P1 | L |
| FEAT-102 | RewardSequenceCoordinator — State machine điều phối chuỗi nhận thưởng đa tầng | Feature | P0 | M |
| FEAT-103 | CardFlip 3D & Gleam Sweep — Lật thẻ bài 3D phối cảnh kèm vệt sáng quét kim loại | Feature | P1 | M |
| ENH-99 | Sequential Staggered StarBurst cho ProgressBarStars và VictoryCard | Enhancement | P1 | S |
| FEAT-104 | JankDetector & Live Frame Graph cho Debug QA Overlay | Feature | P1 | M |
| FEAT-105 | Iris / Shape Wipe Transition — Chuyển cảnh vòng tròn & ngôi sao co giãn | Feature | P1 | M |
| ENH-100 | SpringPhysics Simulation cho nút bấm và popup (vật lý lò xo thực) | Enhancement | P1 | M |
| FEAT-106 | PooledParticleBurst — Hệ thống hạt nổ tối ưu Zero-GC tích hợp ObjectPool | Feature | P1 | M |

### Wave 2: Juice & Micro-Interactions (Tương tác tinh tế)
| ID | Tiêu đề | Loại | Priority | Effort |
|---|---|---|---|---|
| FEAT-107 | JuicyFeedback — Tự động đồng bộ Âm thanh + Rung theo preset cho Widget | Feature | P0 | S |
| ENH-101 | Pulsing / Radar BadgeDot — Chấm thông báo nhịp tim & sóng lan toả | Enhancement | P2 | S |
| FEAT-108 | GoldenShimmerText — Vệt sáng kim tuyến quét ngang chữ & điểm số lớn | Feature | P1 | S |

### Wave 3: Casual Game Core Widgets & Minigames (Cơ chế game kinh điển)
| ID | Tiêu đề | Loại | Priority | Effort |
|---|---|---|---|---|
| FEAT-109 | BattlePassRoad / MilestoneTrack — Đường ray mốc phần thưởng Free & VIP | Feature | P0 | L |
| FEAT-110 | MysteryChest & Sunburst God Rays — Mở rương báu bật nắp & hào quang quay | Feature | P0 | M |
| FEAT-111 | PiggyBankVault — Heo đất tích luỹ xu theo ván chơi kèm hiệu ứng đầy bình | Feature | P1 | M |
| FEAT-112 | ScratchCard — Thẻ cào may mắn tương tác ngón tay lộ phần thưởng | Feature | P1 | L |

### Wave 4: Casual App Foundation Widgets (Giao diện ứng dụng hoàn chỉnh)
| ID | Tiêu đề | Loại | Priority | Effort |
|---|---|---|---|---|
| FEAT-113 | CandyRadioGroup & CandyCheckboxTile — Lựa chọn radio và hộp kiểm bo nảy | Feature | P1 | S |
| FEAT-114 | ExpandablePanel / AccordionTile — Thẻ nội dung gập/mở trơn tru | Feature | P1 | S |
| FEAT-115 | StaggeredAnimatedGrid — Lưới card danh mục/shop hiệu ứng gợn sóng cascade | Feature | P1 | M |
| FEAT-116 | CandySearchBar & FilterChipRow — Thanh tìm kiếm kèm hàng tag lọc chip nảy | Feature | P1 | M |
| FEAT-117 | CandySlider — Thanh trượt âm lượng/giá trị bo tròn với con trượt squash nảy | Feature | P0 | M |
| FEAT-118 | RadialActionMenu — Nút tròn FAB bung toả menu cánh cung nan quạt | Feature | P1 | M |
| FEAT-119 | SwipeableActionTile — Thẻ danh sách vuốt lộ nút xoá/nhận quà kèm haptic | Feature | P1 | M |

### Wave 5: Social & Live-Ops Presence (Mạng xã hội & phòng chơi)
| ID | Tiêu đề | Loại | Priority | Effort |
|---|---|---|---|---|
| FEAT-120 | StackedAvatarGroup — Cụm avatar bạn bè/clan xếp chồng chéo kèm số dư +N | Feature | P2 | S |
| FEAT-121 | FloatingEmojiBurst — Emoji tương tác thả tim/cười bay lượn từ góc màn hình | Feature | P2 | S |
| FEAT-122 | WheelPointerClicker — Kim chỉ vòng quay nảy rung vật lý theo từng nan quạt | Feature | P1 | S |

## 3. Quy chuẩn triển khai & Tiêu chuẩn chấp nhận (DoD - Definition of Done)
1. **Kiểm thử 3 lớp bắt buộc**:
   - Mọi task logic/state phải có Unit test độc lập.
   - Mọi widget phải có Widget test phủ mount/unmount, tap, gesture, drag, state change, và `reducedMotion`.
   - Mọi widget quan trọng phải có màn hình mẫu demo trong `example/` và kiểm tra thiết bị thật (Integration test).
2. **Hiệu năng & Animation**:
   - Lập baseline FPS/frame-time cho workload và thiết bị trước; báo p50/p95, jank count và phép đo cụ thể. Không dùng headline “60 FPS” nếu chưa đo đủ điều kiện.
   - Kiểm tra tài nguyên theo vòng đời: `AnimationController`, `Timer`, `StreamSubscription` được dispose; thêm test phát hiện ticker/timer rò rỉ.
   - Dùng `RepaintBoundary` có đo đạc; không thêm ranh giới repaint máy móc nếu làm tăng layer/memory mà không giảm repaint.
