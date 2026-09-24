import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/deep_link_command_router.dart';
import 'package:roy_casual_kit/core/invite_friend_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same testing seam `share_helper_test.dart` already uses — captures the
/// `ShareParams` `shareInvite` actually passed through, without touching a
/// real platform channel.
class _FakeSharePlatform extends SharePlatform {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult('', ShareResultStatus.success);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;
  late DeepLinkCommandRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
    router = DeepLinkCommandRouter(
      routes: [InviteFriendCoordinator.route(scheme: 'myapp')],
    );
    router.markReady();
  });

  group('InviteFriendCoordinator: codeFor (pure)', () {
    test('cùng id -> luôn ra cùng 1 mã qua nhiều lần gọi', () {
      final a = InviteFriendCoordinator.codeFor('player-123');
      final b = InviteFriendCoordinator.codeFor('player-123');
      final c = InviteFriendCoordinator.codeFor('player-123');
      expect(a, b);
      expect(b, c);
    });

    test('id khác nhau -> ra mã khác nhau', () {
      final a = InviteFriendCoordinator.codeFor('player-123');
      final b = InviteFriendCoordinator.codeFor('player-456');
      expect(a, isNot(b));
    });
  });

  group('InviteFriendCoordinator: nhận diện deep link thật qua router', () {
    test(
      'link mời hợp lệ đi qua DeepLinkCommandRouter thật -> đánh dấu đã '
      'redeem đúng code',
      () async {
        final coordinator = InviteFriendCoordinator(
          router: router,
          storage: store,
        );
        expect(coordinator.hasRedeemedInvite, isFalse);

        final result = await router.handleUri(
          Uri.parse('myapp://invite?code=ABC123'),
        );

        expect(result.outcome, DeepLinkOutcome.dispatched);
        expect(coordinator.hasRedeemedInvite, isTrue);
        expect(coordinator.redeemedInviteCode, 'ABC123');
      },
    );

    test(
      'đã redeem 1 mã -> mở link mời KHÁC lần 2 KHÔNG ghi đè, KHÔNG tính '
      'thêm',
      () async {
        final coordinator = InviteFriendCoordinator(
          router: router,
          storage: store,
        );

        await router.handleUri(Uri.parse('myapp://invite?code=FIRST'));
        expect(coordinator.redeemedInviteCode, 'FIRST');

        // dedupeCooldown mặc định 3s sẽ chặn CÙNG URI lặp lại — dùng code
        // khác hẳn để chắc chắn đây là kiểm tra đúng logic
        // "chỉ redeem 1 lần" của coordinator, không phải dedupe của router.
        await router.handleUri(Uri.parse('myapp://invite?code=SECOND'));

        expect(coordinator.redeemedInviteCode, 'FIRST');
      },
    );

    test(
      'link không có param code -> không throw, không đánh dấu redeem',
      () async {
        final coordinator = InviteFriendCoordinator(
          router: router,
          storage: store,
        );

        final result = await router.handleUri(Uri.parse('myapp://invite'));

        expect(result.outcome, DeepLinkOutcome.dispatched);
        expect(coordinator.hasRedeemedInvite, isFalse);
      },
    );

    test(
      'link không khớp route nào (scheme khác) -> router reject, không '
      'đụng coordinator',
      () async {
        final coordinator = InviteFriendCoordinator(
          router: router,
          storage: store,
        );

        final result = await router.handleUri(
          Uri.parse('otherapp://invite?code=ABC'),
        );

        expect(result.outcome, DeepLinkOutcome.rejected);
        expect(coordinator.hasRedeemedInvite, isFalse);
      },
    );
  });

  group('InviteFriendCoordinator: shareInvite', () {
    final fakePlatform = _FakeSharePlatform();
    SharePlatform.instance = fakePlatform;

    setUp(() => fakePlatform.lastParams = null);

    test('mặc định -> share text chứa đúng mã mời của playerId', () async {
      final coordinator = InviteFriendCoordinator(
        router: router,
        storage: store,
      );
      final expectedCode = InviteFriendCoordinator.codeFor('player-123');

      await coordinator.shareInvite('player-123');

      expect(fakePlatform.lastParams, isNotNull);
      expect(fakePlatform.lastParams!.text, contains(expectedCode));
    });

    test('có messageBuilder -> dùng đúng message tuỳ chỉnh, vẫn nhận đúng code', () async {
      final coordinator = InviteFriendCoordinator(
        router: router,
        storage: store,
      );
      final expectedCode = InviteFriendCoordinator.codeFor('player-123');
      String? capturedCode;

      await coordinator.shareInvite(
        'player-123',
        messageBuilder: (code) {
          capturedCode = code;
          return 'Custom invite: $code';
        },
      );

      expect(capturedCode, expectedCode);
      expect(fakePlatform.lastParams!.text, 'Custom invite: $expectedCode');
    });
  });
}
