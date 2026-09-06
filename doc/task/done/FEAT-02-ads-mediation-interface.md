---
id: FEAT-02
title: Ads mediation adapter interface (Rewarded/Interstitial)
type: feature
priority: P0
effort: M
source: agy + fork nội bộ
---

## Vì sao cần
Quảng cáo (rewarded/interstitial) gần như bắt buộc với casual/idle game
free-to-play. Package hiện chưa có abstraction nào cho việc này.

## Đề xuất phạm vi
Chỉ cần **interface trung lập**, KHÔNG implement SDK ads thật (tránh kéo thêm
dependency nặng vào 1 base kit):
```dart
abstract class RewardedAdProvider {
  Future<bool> isReady();
  Future<bool> show(); // true nếu người dùng xem hết và nhận thưởng
}
abstract class InterstitialAdProvider {
  Future<bool> isReady();
  Future<void> show();
}
```
App dùng kit tự implement adapter cắm AdMob/Applovin/... vào interface này.

## Acceptance criteria
- [ ] 2 interface tồn tại trong `lib/core/` (ví dụ `ads_provider.dart`), có doc comment rõ đây là seam để app tự cắm SDK.
- [ ] 1 fake implementation trong test để chứng minh interface dùng được.

## Quyết định
**Từ chối, không làm.** Chủ repo (Roy) không muốn quảng cáo trong base kit này.
Không phải vấn đề kỹ thuật — quyết định phạm vi sản phẩm.
