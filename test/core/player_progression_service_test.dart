import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

const _validCurve = [
  LevelDefinition(level: 1, xpToNext: 100),
  LevelDefinition(level: 2, xpToNext: 200),
  LevelDefinition(
    level: 3,
    xpToNext: 0,
    unlockRewardLines: [RewardLine(currency: 'gem', amount: 50)],
  ),
];

void main() {
  group('validateLevelCurve', () {
    test(
      'curve hợp lệ (contiguous, tăng dần, kết thúc xpToNext=0) trả null',
      () {
        expect(validateLevelCurve(_validCurve), isNull);
      },
    );

    test('rỗng bị reject', () {
      expect(validateLevelCurve(const []), isNotNull);
    });

    test('level trùng (duplicate) bị reject', () {
      final curve = [
        const LevelDefinition(level: 1, xpToNext: 100),
        const LevelDefinition(level: 1, xpToNext: 200),
      ];
      expect(validateLevelCurve(curve), isNotNull);
    });

    test('level thiếu (gap, 1 rồi nhảy sang 3) bị reject', () {
      final curve = [
        const LevelDefinition(level: 1, xpToNext: 100),
        const LevelDefinition(level: 3, xpToNext: 0),
      ];
      expect(validateLevelCurve(curve), isNotNull);
    });

    test('level cuối phải có xpToNext = 0 (đánh dấu max level)', () {
      final curve = [
        const LevelDefinition(level: 1, xpToNext: 100),
        const LevelDefinition(level: 2, xpToNext: 200), // thiếu marker max
      ];
      expect(validateLevelCurve(curve), isNotNull);
    });

    test('curve giảm dần (không tăng) bị reject', () {
      final curve = [
        const LevelDefinition(level: 1, xpToNext: 200),
        const LevelDefinition(level: 2, xpToNext: 100),
        const LevelDefinition(level: 3, xpToNext: 0),
      ];
      expect(validateLevelCurve(curve), isNotNull);
    });

    test('overflow (cộng dồn vượt giới hạn hỗ trợ) bị reject', () {
      final curve = [
        const LevelDefinition(level: 1, xpToNext: 0x7fffffff),
        const LevelDefinition(level: 2, xpToNext: 0x7fffffff),
        const LevelDefinition(level: 3, xpToNext: 0),
      ];
      expect(validateLevelCurve(curve), isNotNull);
    });
  });

  group('levelForTotalXp / xpIntoLevelForTotalXp (pure)', () {
    test('0 XP → level 1, xpIntoLevel 0', () {
      expect(levelForTotalXp(_validCurve, 0), 1);
      expect(xpIntoLevelForTotalXp(_validCurve, 0), 0);
    });

    test('99 XP vẫn ở level 1', () {
      expect(levelForTotalXp(_validCurve, 99), 1);
      expect(xpIntoLevelForTotalXp(_validCurve, 99), 99);
    });

    test('đúng 100 XP lên level 2, xpIntoLevel về 0', () {
      expect(levelForTotalXp(_validCurve, 100), 2);
      expect(xpIntoLevelForTotalXp(_validCurve, 100), 0);
    });

    test('nhảy nhiều level cùng lúc (300 XP → level 3, max)', () {
      expect(levelForTotalXp(_validCurve, 300), 3);
    });

    test('vượt xa max level vẫn dừng ở level cuối (không tràn)', () {
      expect(levelForTotalXp(_validCurve, 999999), 3);
      expect(xpIntoLevelForTotalXp(_validCurve, 999999), 0);
    });
  });

  group('PlayerProgressionService: grantXp cơ bản', () {
    late StorageService storage;
    late PlayerProgressionService service;

    setUp(() {
      storage = StorageService(null);
      service = PlayerProgressionService(
        storage: storage,
        levelCurve: _validCurve,
      )..onInit();
    });

    test('khởi tạo: level 1, totalXpEarned 0', () {
      expect(service.snapshot.value.level, 1);
      expect(service.snapshot.value.totalXpEarned, 0);
    });

    test('grantXp 50: vẫn level 1, xpIntoLevel 50', () async {
      final result = await service.grantXp(amount: 50, transactionId: 'tx1');
      expect(result, isA<SdkSuccess<PlayerProgressionSnapshot>>());
      expect(service.snapshot.value.level, 1);
      expect(service.snapshot.value.xpIntoLevel, 50);
    });

    test('grantXp amount <= 0 hoặc transactionId rỗng bị reject', () async {
      final r1 = await service.grantXp(amount: 0, transactionId: 'tx1');
      expect(r1, isA<SdkFailure<PlayerProgressionSnapshot>>());
      final r2 = await service.grantXp(amount: 10, transactionId: '');
      expect(r2, isA<SdkFailure<PlayerProgressionSnapshot>>());
    });

    test(
      'grantXp cùng transactionId 2 lần: idempotent, không cộng dồn 2 lần',
      () async {
        await service.grantXp(amount: 60, transactionId: 'dup');
        await service.grantXp(amount: 60, transactionId: 'dup');
        expect(service.snapshot.value.totalXpEarned, 60);
      },
    );
  });

  group('PlayerProgressionService: multi-level jump + unlock reward', () {
    test(
      'grantXp vượt qua nhiều level: mỗi unlock reward được cấp đúng 1 lần qua pipeline',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(storage: storage);
        final pipeline = RewardTransactionPipeline(wallet: wallet);
        final service = PlayerProgressionService(
          storage: storage,
          levelCurve: _validCurve,
          pipeline: pipeline,
        )..onInit();
        final levelUps = <LevelUpEvent>[];
        service.onLevelUp.listen((e) {
          if (e != null) levelUps.add(e);
        });

        // 300 XP nhảy thẳng từ level 1 lên level 3 (max) — phải bắn đúng 2
        // level-up event (lên 2, lên 3), level 3 mới có reward gem.
        await service.grantXp(amount: 300, transactionId: 'big-grant');

        expect(service.snapshot.value.level, 3);
        expect(levelUps.map((e) => e.level).toList(), [2, 3]);
        expect(wallet.balanceOf('gem'), 50);

        // Gọi lại cùng transactionId — không được cấp reward gem lần 2.
        await service.grantXp(amount: 300, transactionId: 'big-grant');
        expect(wallet.balanceOf('gem'), 50);
      },
    );

    test('level không có unlockRewardLines thì không gọi pipeline', () async {
      final storage = StorageService(null);
      final wallet = EconomyWallet(storage: storage);
      final pipeline = RewardTransactionPipeline(wallet: wallet);
      final service = PlayerProgressionService(
        storage: storage,
        levelCurve: _validCurve,
        pipeline: pipeline,
      )..onInit();

      await service.grantXp(amount: 100, transactionId: 'to-level-2');

      expect(service.snapshot.value.level, 2);
      expect(wallet.balanceOf('gem'), 0);
    });
  });

  group('PlayerProgressionService: max level', () {
    test(
      'grantXp thêm sau khi đã max level: level không vượt quá curve, không unlock thêm',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(storage: storage);
        final pipeline = RewardTransactionPipeline(wallet: wallet);
        final service = PlayerProgressionService(
          storage: storage,
          levelCurve: _validCurve,
          pipeline: pipeline,
        )..onInit();

        await service.grantXp(amount: 300, transactionId: 'reach-max');
        expect(service.snapshot.value.level, 3);
        expect(wallet.balanceOf('gem'), 50);

        await service.grantXp(amount: 1000, transactionId: 'past-max');
        expect(service.snapshot.value.level, 3);
        // Không unlock reward lần 2 dù gọi grantXp thêm sau khi đã max.
        expect(wallet.balanceOf('gem'), 50);
      },
    );
  });

  group('PlayerProgressionService: persist qua restart', () {
    test(
      'level/XP/unlock giữ nguyên sau khi tạo lại service mới cùng storage',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(storage: storage);
        final pipeline = RewardTransactionPipeline(wallet: wallet);
        final first = PlayerProgressionService(
          storage: storage,
          levelCurve: _validCurve,
          pipeline: pipeline,
        )..onInit();
        await first.grantXp(amount: 150, transactionId: 'tx1');
        expect(first.snapshot.value.level, 2);

        final second = PlayerProgressionService(
          storage: storage,
          levelCurve: _validCurve,
          pipeline: pipeline,
        )..onInit();
        expect(second.snapshot.value.level, 2);
        expect(second.snapshot.value.totalXpEarned, 150);

        // Transaction cũ vẫn được nhớ qua restart — gọi lại không cộng dồn.
        await second.grantXp(amount: 150, transactionId: 'tx1');
        expect(second.snapshot.value.totalXpEarned, 150);
      },
    );
  });

  group('PlayerProgressionService: corrupt save', () {
    test(
      'save hỏng (không phải JSON hợp lệ) không throw, không tự tăng quyền lợi',
      () async {
        final storage = StorageService(null);
        await storage.setString('player_progression_v1', 'not valid json {{{');

        final service = PlayerProgressionService(
          storage: storage,
          levelCurve: _validCurve,
        )..onInit();

        expect(service.snapshot.value.level, 1);
        expect(service.snapshot.value.totalXpEarned, 0);
        expect(() => service.snapshot.value, returnsNormally);
      },
    );
  });

  group('PlayerProgressionService: config curve invalid', () {
    test('constructor throw ArgumentError rõ ràng khi curve không hợp lệ', () {
      expect(
        () => PlayerProgressionService(
          storage: StorageService(null),
          levelCurve: const [LevelDefinition(level: 1, xpToNext: -5)],
        ),
        throwsArgumentError,
      );
    });
  });
}
