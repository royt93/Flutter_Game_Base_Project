# QC Test Cases — Neon Jewels

> Bộ test case thủ công cho QC. Mỗi file = 1 nhóm tính năng.  
> Cập nhật: 2026-06-21

---

## Danh sách file

| File | Nhóm | Priority | Số TC |
|------|------|----------|-------|
| [TC-01_first_launch.md](TC-01_first_launch.md) | First Launch & Home | P0 | 6 |
| [TC-02_campaign.md](TC-02_campaign.md) | Campaign (Level Select + Gameplay) | P0 | 16 |
| [TC-03_side_modes.md](TC-03_side_modes.md) | 11 Side Modes | P1 | 12 |
| [TC-04_versus.md](TC-04_versus.md) | Versus Mode | P1 | 4 |
| [TC-05_booster_economy.md](TC-05_booster_economy.md) | Booster, Shop, Xu, Lucky Wheel | P1 | 9 |
| [TC-06_meta_progression.md](TC-06_meta_progression.md) | Battle Pass, Season, Achievement, Collection, Temple, Tree, Card | P1 | 8 |
| [TC-07_settings_i18n.md](TC-07_settings_i18n.md) | Settings, i18n, Audio, Guide | P1 | 5 |
| [TC-08_ghost_replay.md](TC-08_ghost_replay.md) | Ghost Replay, DDA/Pity, Win Streak | P2 | 5 |
| [TC-09_advanced_gameplay.md](TC-09_advanced_gameplay.md) | Conveyor, Portal, Dispenser, Flow, Cage, Order, Jam | P2 | 11 |
| [TC-10_regression_edge_cases.md](TC-10_regression_edge_cases.md) | Regression & Edge Cases | P1 | 12 |

**Tổng cộng: ~88 test case**

---

## Hướng dẫn chạy

### Priority thực hiện
```
P0 → P1 → P2
P0 bắt buộc mỗi build (smoke test ~20 phút)
P1 bắt buộc trước release (~2 giờ)  
P2 mỗi sprint hoặc khi thay đổi cơ chế liên quan
```

### Cách đánh dấu kết quả

Trong mỗi bảng test, điền cột **Kết quả** theo ký hiệu:
- ✅ Pass
- ❌ Fail — ghi chú mô tả lỗi
- ⚠️ Partial — hoạt động nhưng UX kém
- ⏭️ Skip — không applicable với build/device hiện tại

### Thiết bị khuyến nghị
| Loại | Thiết bị | Lý do |
|------|----------|-------|
| **Bắt buộc** | Redmi Note 911adbeb | Device test chính dự án |
| Nên có | Thiết bị màn 5" | Verify không overflow |
| Nên có | iOS (nếu build) | Cross-platform |

---

## Luồng full E2E (Happy Path)

Chạy theo thứ tự để cover luồng đầy đủ từ install đến meta:

```
1. Cài app mới (fresh install)
2. TC-01-01: Cold start, Home load
3. TC-01-02: Nhận thưởng đăng nhập ngày 1
4. TC-02-01 → TC-02-08: Chọn màn 1, chơi, thắng
5. TC-02-10 → TC-02-11: Kiểm tra mạng
6. TC-05-07: Quay Lucky Wheel
7. TC-06-01 → TC-06-02: Kiểm tra Battle Pass XP
8. TC-03-10: Chơi Daily Challenge, nhận xu
9. TC-07-02: Đổi ngôn ngữ sang tiếng Việt
10. TC-07-01: Tắt/bật âm thanh
11. TC-10-04: Reset tiến độ (cuối session test)
```

---

## Các điểm dễ fail nhất (kinh nghiệm)

| Vấn đề | TC liên quan | Ghi chú |
|--------|-------------|---------|
| Dialog không hiển thị sau khi hết lượt | TC-10-01, TC-10-02 | Get.dialog no-op trong Flame |
| MỤC TIÊU jelly hiện 0/0 | TC-10-03 | jellyTotal phải là RxInt |
| Reset không clear in-memory BP/Season | TC-10-04 | resetState() phải gọi tất cả controller |
| Xu overflow sang âm | TC-10-06 | clamp int32 |
| Dấu tiếng Việt bị mất | TC-07-02, TC-10-07 | Baloo2, không Orbitron |
| Side mode ảnh hưởng campaign | TC-10-05 | isSideMode check |
| Daily reward nhận 2 lần (chỉnh giờ lùi) | TC-05-09 | effectiveDay max-day |
