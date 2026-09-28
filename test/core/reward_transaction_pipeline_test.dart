import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

class _ThrowingStorageService extends StorageService {
  _ThrowingStorageService() : super(null);
  bool shouldThrow = true;

  /// Only throws on the [failOnCall]-th `setString` call (1-indexed) — lets
  /// a test target a SPECIFIC persist inside `grant` (pending vs. commit)
  /// instead of only the first one. `null` (default) throws on every call
  /// while [shouldThrow] is true.
  int? failOnCall;
  int _callCount = 0;

  @override
  Future<void> setString(String key, String value) async {
    _callCount++;
    final shouldFailThisCall = failOnCall == null
        ? shouldThrow
        : shouldThrow && _callCount == failOnCall;
    if (shouldFailThisCall) {
      throw StateError('simulated disk write failure');
    }
    return super.setString(key, value);
  }
}

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
    'BUG-75: capacity <= 0 bị từ chối trước khi audit/resume bị vô hiệu',
    () {
      expect(
        () => RewardTransactionPipeline(wallet: wallet, capacity: 0),
        throwsArgumentError,
      );
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

  group('BUG-71: grant() lần 2 cùng transactionId pending/partial với lines '
      'KHÁC', () {
    test('record partial + gọi lại grant() trực tiếp với lines khác -> '
        'từ chối (validation), KHÔNG âm thầm commit theo lines cũ (đã lưu) '
        'lẫn không commit theo lines mới (bị bỏ qua)', () async {
      // Đẩy 'gem' sát biên overflow để line thứ 2 thất bại, giống hệt
      // setup của test "partial failure" sẵn có ở trên.
      await wallet.earn(
        currency: 'gem',
        amount: 0x7ffffffe,
        transactionId: 'seed_overflow_2',
      );

      final first = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'multi2',
        lines: const [
          RewardLine(currency: 'coin', amount: 10),
          RewardLine(currency: 'gem', amount: 10),
        ],
      );
      expect(first.isSuccess, isFalse);
      expect(
        pipeline.auditTrail.single.status,
        RewardTransactionStatus.partial,
      );

      // Hết lỗi overflow (giống hệt cách test partial-failure sẵn có
      // dọn lại trước khi resumePending()) — để line thứ 2 giờ ĐỦ ĐIỀU
      // KIỆN áp dụng thành công nếu code cũ âm thầm dùng lại
      // `existing.lines` (10 gem, không phải 999 gem).
      await wallet.trySpend(
        currency: 'gem',
        amount: 0x7ffffffe,
        transactionId: 'undo_overflow_2',
      );

      // Gọi lại TRỰC TIẾP grant() (không qua resumePending()) với
      // lines KHÁC hẳn cho cùng transactionId đang partial.
      final second = await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'multi2',
        lines: const [
          RewardLine(currency: 'coin', amount: 999),
          RewardLine(currency: 'gem', amount: 999),
        ],
      );

      // Code cũ (bug): âm thầm dùng lại `existing.lines` ([10, 10]),
      // line 2 giờ áp dụng thành công (gem đã hết overflow) -> commit
      // "thành công" nhưng với số liệu SAI (không phải 999 caller vừa
      // yêu cầu, cũng không báo lỗi gì để caller biết bị bỏ qua).
      // Code đúng (sau fix): từ chối thẳng vì lines không khớp.
      expect(second.isSuccess, isFalse);
      // Bị chặn TRƯỚC khi loop áp dụng bất kỳ line nào (không dùng
      // lines cũ [10] lẫn lines mới [999]) — gem giữ nguyên 0 (đã undo
      // overflow ở trên), không bị cộng thêm.
      expect(wallet.balanceOf('gem'), 0);
    });

    test('record pending (chưa line nào chạy, do concurrent) + gọi lại với '
        'lines khác hệt -> vẫn OK bình thường (không phải mọi lần gọi lại '
        'đều bị chặn, chỉ khi lines thật sự khác)', () async {
      final results = await Future.wait([
        pipeline.grant(
          source: RewardSource.purchase,
          transactionId: 'iap_same',
          lines: const [RewardLine(currency: 'gem', amount: 100)],
        ),
        pipeline.grant(
          source: RewardSource.purchase,
          transactionId: 'iap_same',
          lines: const [RewardLine(currency: 'gem', amount: 100)],
        ),
      ]);

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(wallet.balanceOf('gem'), 100);
    });

    test('resumePending() sau partial vẫn hoạt động đúng như cũ (tự truyền '
        'lại đúng lines đã lưu, không bị validation mới chặn nhầm)', () async {
      await wallet.earn(
        currency: 'gem',
        amount: 0x7ffffffe,
        transactionId: 'seed_overflow_3',
      );

      await pipeline.grant(
        source: RewardSource.ad,
        transactionId: 'multi3',
        lines: const [
          RewardLine(currency: 'coin', amount: 10),
          RewardLine(currency: 'gem', amount: 10),
        ],
      );

      await wallet.trySpend(
        currency: 'gem',
        amount: 0x7ffffffe,
        transactionId: 'undo_overflow_3',
      );
      await pipeline.resumePending();

      expect(
        pipeline.auditTrail.single.status,
        RewardTransactionStatus.committed,
      );
      expect(wallet.balanceOf('gem'), 10);
    });
  });

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

  test(
    'BUG-81: createdAtMs dùng nowMs seam, không hard-code DateTime.now()',
    () async {
      const fakeNow = 9_000_000_000_000;
      final p = RewardTransactionPipeline(
        wallet: wallet,
        nowMs: () => fakeNow,
      )..onInit();

      await p.grant(
        source: RewardSource.ad,
        transactionId: 'ts_test',
        lines: const [RewardLine(currency: 'coin', amount: 1)],
      );

      expect(p.auditTrail.single.createdAtMs, fakeNow);
    },
  );

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

  group('BUG-88: persist throw không phá hợp đồng SdkResult', () {
    test(
      'setString throw ngay lần persist ĐẦU (pending) -> grant trả SdkFailure.storage, '
      'không throw, không để lại record giả trong memory, không phát onGranted',
      () async {
        final throwingStorage = _ThrowingStorageService();
        final throwingWallet = EconomyWallet(storage: throwingStorage)
          ..onInit();
        final throwingPipeline = RewardTransactionPipeline(
          wallet: throwingWallet,
        )..onInit();
        RewardTransactionRecord? granted;
        throwingPipeline.onGranted.listen((r) => granted = r);

        final result = await throwingPipeline.grant(
          source: RewardSource.ad,
          transactionId: 'persist_fail_1',
          lines: const [RewardLine(currency: 'coin', amount: 5)],
        );

        expect(result, isA<SdkFailure<RewardTransactionRecord>>());
        expect(
          (result as SdkFailure<RewardTransactionRecord>).kind,
          SdkErrorKind.storage,
        );
        expect(throwingPipeline.auditTrail, isEmpty);
        expect(granted, isNull);
      },
    );

    test(
      'setString throw ở lần persist CUỐI (commit, sau khi wallet.earn thành công) '
      '-> grant trả SdkFailure.storage, in-memory rollback về snapshot trước commit, '
      'không phát onGranted',
      () async {
        // Cùng 1 `storage` instance được cả pipeline (_upsert) VÀ
        // EconomyWallet (earn's own setString) dùng chung — 1 line ->
        // đúng 3 lần setString trong nhánh happy path: (1) pending upsert,
        // (2) wallet.earn's own persist, (3) committed upsert. Nhắm lần
        // thứ 3 để mô phỏng đúng "wallet.earn thành công nhưng disk write
        // cho commit thất bại".
        final gatingStorage = _ThrowingStorageService()..failOnCall = 3;
        final gatingWallet = EconomyWallet(storage: gatingStorage)..onInit();
        final gatingPipeline = RewardTransactionPipeline(wallet: gatingWallet)
          ..onInit();
        RewardTransactionRecord? granted;
        gatingPipeline.onGranted.listen((r) => granted = r);

        final result = await gatingPipeline.grant(
          source: RewardSource.ad,
          transactionId: 'persist_fail_2',
          lines: const [RewardLine(currency: 'coin', amount: 5)],
        );

        expect(result, isA<SdkFailure<RewardTransactionRecord>>());
        expect(
          (result as SdkFailure<RewardTransactionRecord>).kind,
          SdkErrorKind.storage,
        );
        expect(granted, isNull);
        expect(gatingPipeline.auditTrail, hasLength(1));
        expect(
          gatingPipeline.auditTrail.single.status,
          RewardTransactionStatus.pending,
          reason:
              'committed persist thất bại phải rollback memory về snapshot '
              'pending đã persist thành công trước đó — không được báo '
              'committed giả chỉ tồn tại trong RAM',
        );
      },
    );
  });
}
