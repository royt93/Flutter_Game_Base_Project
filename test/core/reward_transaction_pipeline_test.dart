import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/storage_service.dart';

void main() {
  late StorageService storage;
  late EconomyWallet wallet;
  late RewardTransactionPipeline pipeline;

  setUp(() {
    storage = StorageService(null);
    wallet = EconomyWallet(storage: storage)..onInit();
    pipeline = RewardTransactionPipeline(wallet: wallet)..onInit();
  });

  test(
    'từ chối request rỗng/không hợp lệ, không đụng wallet/audit trail',
    () async {
      final empty = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: '',
        lines: const [RewardLine(currency: 'coin', amount: 10)],
      );
      final noLines = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'tx1',
        lines: const [],
      );
      final badLine = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'tx2',
        lines: const [RewardLine(currency: 'coin', amount: 0)],
      );

      expect(empty.isSuccess, isFalse);
      expect(noLines.isSuccess, isFalse);
      expect(badLine.isSuccess, isFalse);
      expect(wallet.balanceOf('coin'), 0);
      expect(pipeline.auditTrail, isEmpty);
    },
  );

  test(
    'grant 1 line: cộng đúng wallet, record committed trong audit trail',
    () async {
      final result = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'ad1',
        lines: const [RewardLine(currency: 'coin', amount: 50)],
      );

      expect(result.isSuccess, isTrue);
      expect(wallet.balanceOf('coin'), 50);
      expect(
        pipeline.auditTrail.single.status,
        RewardTransactionStatus.committed,
      );
      expect(pipeline.auditTrail.single.transactionId, 'ad1');
    },
  );

  test(
    'grant nhiều line cùng 1 transactionId: mỗi currency cộng đúng, không đụng nhau',
    () async {
      await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'ad2',
        lines: const [
          RewardLine(currency: 'coin', amount: 50),
          RewardLine(currency: 'energy', amount: 1),
        ],
      );

      expect(wallet.balanceOf('coin'), 50);
      expect(wallet.balanceOf('energy'), 1);
    },
  );

  test(
    'gọi lại đúng transactionId lần 2: không cộng thêm, trả về record cũ',
    () async {
      await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'ad3',
        lines: const [RewardLine(currency: 'coin', amount: 20)],
      );
      final second = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'ad3',
        lines: const [RewardLine(currency: 'coin', amount: 20)],
      );

      expect(second.isSuccess, isTrue);
      expect(wallet.balanceOf('coin'), 20);
      expect(pipeline.auditTrail.length, 1);
    },
  );

  test('concurrent callback trùng transactionId: chỉ cộng một lần', () async {
    final results = await Future.wait([
      pipeline.grant(
        source: RewardSource.purchase,
        transactionId: 'iap1',
        lines: const [RewardLine(currency: 'gem', amount: 100)],
      ),
      pipeline.grant(
        source: RewardSource.purchase,
        transactionId: 'iap1',
        lines: const [RewardLine(currency: 'gem', amount: 100)],
      ),
    ]);

    expect(results.every((r) => r.isSuccess), isTrue);
    expect(wallet.balanceOf('gem'), 100);
    expect(pipeline.auditTrail.length, 1);
  });

  test(
    'restart: instance mới cùng storage đọc lại đúng audit trail, không cộng lại',
    () async {
      await pipeline.grant(
        source: RewardSource.dailyLogin,
        transactionId: 'login1',
        lines: const [RewardLine(currency: 'coin', amount: 5)],
      );

      final restartedWallet = EconomyWallet(storage: storage)..onInit();
      final restarted = RewardTransactionPipeline(wallet: restartedWallet)
        ..onInit();

      expect(
        restarted.auditTrail.single.status,
        RewardTransactionStatus.committed,
      );
      final again = await restarted.grant(
        source: RewardSource.dailyLogin,
        transactionId: 'login1',
        lines: const [RewardLine(currency: 'coin', amount: 5)],
      );
      expect(again.isSuccess, isTrue);
      expect(restartedWallet.balanceOf('coin'), 5);
    },
  );

  test(
    'partial failure: line sau lỗi (overflow) -> line trước vẫn giữ, record partial, resumePending() hoàn tất sau khi hết lỗi',
    () async {
      // Đẩy 'gem' sát biên overflow int32 để line thứ 2 của transaction
      // dưới đây thất bại validation trong EconomyWallet._apply.
      await wallet.earn(
        currency: 'gem',
        amount: 0x7ffffffe,
        transactionId: 'seed_overflow',
      );

      final result = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'multi1',
        lines: const [
          RewardLine(currency: 'coin', amount: 10),
          RewardLine(currency: 'gem', amount: 10),
        ],
      );

      expect(result.isSuccess, isFalse);
      expect(wallet.balanceOf('coin'), 10); // line 1 vẫn giữ, không rollback
      expect(wallet.balanceOf('gem'), 0x7ffffffe); // line 2 chưa áp dụng
      expect(
        pipeline.auditTrail.single.status,
        RewardTransactionStatus.partial,
      );

      // Giảm gem xuống để line 2 hợp lệ được, rồi resume.
      await wallet.trySpend(
        currency: 'gem',
        amount: 0x7ffffffe,
        transactionId: 'undo_overflow',
      );
      await pipeline.resumePending();

      expect(
        pipeline.auditTrail.single.status,
        RewardTransactionStatus.committed,
      );
      expect(wallet.balanceOf('coin'), 10); // line 1 không bị cộng lại lần 2
      expect(wallet.balanceOf('gem'), 10);
    },
  );

  test(
    'analytics throw không ảnh hưởng kết quả grant/reward đã commit',
    () async {
      final failing = RewardTransactionPipeline(
        wallet: wallet,
        onAnalytics: (_) => throw Exception('analytics down'),
      )..onInit();

      final result = await failing.grant(
        source: RewardSource.ad,
        transactionId: 'ad4',
        lines: const [RewardLine(currency: 'coin', amount: 15)],
      );

      expect(result.isSuccess, isTrue);
      expect(wallet.balanceOf('coin'), 15);
    },
  );

  test(
    'audit trail bounded: quá capacity thì record CŨ NHẤT bị loại',
    () async {
      final bounded = RewardTransactionPipeline(wallet: wallet, capacity: 2)
        ..onInit();

      await bounded.grant(
        source: RewardSource.ad,
        transactionId: 'a',
        lines: const [RewardLine(currency: 'coin', amount: 1)],
      );
      await bounded.grant(
        source: RewardSource.ad,
        transactionId: 'b',
        lines: const [RewardLine(currency: 'coin', amount: 1)],
      );
      await bounded.grant(
        source: RewardSource.ad,
        transactionId: 'c',
        lines: const [RewardLine(currency: 'coin', amount: 1)],
      );

      expect(bounded.auditTrail.length, 2);
      expect(bounded.auditTrail.map((r) => r.transactionId), ['b', 'c']);
      expect(wallet.balanceOf('coin'), 3); // wallet vẫn cộng đủ dù audit bị cắt
    },
  );

  group('adapter tiện ích', () {
    test('grantFromDailyQuest: transactionId theo questId+periodKey', () async {
      final result = await pipeline.grantFromDailyQuest(
        questId: 'q1',
        periodKey: '2026-09-18',
        lines: const [RewardLine(currency: 'coin', amount: 5)],
      );

      expect(result.isSuccess, isTrue);
      expect(pipeline.auditTrail.single.source, RewardSource.dailyQuest);
      expect(pipeline.auditTrail.single.transactionId, contains('q1'));
      expect(pipeline.auditTrail.single.transactionId, contains('2026-09-18'));
    });

    test('grantFromDailyLogin: transactionId theo day+periodKey', () async {
      final result = await pipeline.grantFromDailyLogin(
        day: 3,
        periodKey: 'cycle-1',
        lines: const [RewardLine(currency: 'coin', amount: 5)],
      );

      expect(result.isSuccess, isTrue);
      expect(pipeline.auditTrail.single.source, RewardSource.dailyLogin);
    });

    test(
      'grantFromPurchase: transactionId theo receiptId, giữ receiptMeta',
      () async {
        final result = await pipeline.grantFromPurchase(
          receiptId: 'order_123',
          lines: const [RewardLine(currency: 'gem', amount: 200)],
          receiptMeta: const {'productId': 'gem_pack_small'},
        );

        expect(result.isSuccess, isTrue);
        expect(pipeline.auditTrail.single.source, RewardSource.purchase);
        expect(
          pipeline.auditTrail.single.receiptMeta?['productId'],
          'gem_pack_small',
        );
      },
    );
  });

  test('onGranted phát đúng record sau khi commit', () async {
    RewardTransactionRecord? received;
    pipeline.onGranted.listen((r) => received = r);

    await pipeline.grant(
      source: RewardSource.ad,
      transactionId: 'ad5',
      lines: const [RewardLine(currency: 'coin', amount: 1)],
    );

    expect(received?.transactionId, 'ad5');
  });

  test('.maybe: null khi chưa đăng ký, đúng instance khi đã Get.put', () {
    expect(RewardTransactionPipeline.maybe, isNull);
  });

  group('BUG-40: hydrate ngay trong constructor, không phụ thuộc onInit()', () {
    test(
      'khởi tạo trực tiếp (không gọi onInit()) vẫn đọc đúng auditTrail cũ',
      () async {
        await pipeline.grant(
          source: RewardSource.ad,
          transactionId: 'seed',
          lines: const [RewardLine(currency: 'coin', amount: 10)],
        );

        final direct = RewardTransactionPipeline(wallet: wallet);

        expect(direct.auditTrail, hasLength(1));
        expect(direct.auditTrail.single.transactionId, 'seed');
      },
    );

    test(
      'grant ngay sau khởi tạo trực tiếp không ghi đè mất auditTrail cũ',
      () async {
        await pipeline.grant(
          source: RewardSource.ad,
          transactionId: 'seed',
          lines: const [RewardLine(currency: 'coin', amount: 10)],
        );

        final direct = RewardTransactionPipeline(wallet: wallet);
        await direct.grant(
          source: RewardSource.ad,
          transactionId: 'extra',
          lines: const [RewardLine(currency: 'coin', amount: 5)],
        );

        expect(direct.auditTrail, hasLength(2));
      },
    );
  });
}
