import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/economy_certificate.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/trusted_clock.dart';

const _secret = 'test-certificate-secret';

Future<EconomyWallet> _walletWith(Map<String, int> balances) async {
  final wallet = EconomyWallet(storage: StorageService.to);
  for (final entry in balances.entries) {
    await wallet.earn(
      currency: entry.key,
      amount: entry.value,
      transactionId: 'seed_${entry.key}',
    );
  }
  return wallet;
}

void main() {
  // PurchaseLedgerService/TrustedClockService both read `StorageService.to`
  // (the Get singleton) internally, unlike EconomyWallet (which takes a
  // storage instance directly) — every group below needs 1 registered.
  setUp(() => Get.put(StorageService(null), permanent: true));
  tearDown(Get.reset);

  group('EconomyCertificate.issue + verify: chứng nhận hợp lệ', () {
    test('gộp đúng cả 3 nguồn: balances, ledger, clockJudgement', () async {
      final wallet = await _walletWith({'gems': 100, 'coins': 5000});
      final ledger = PurchaseLedgerService(storageKey: 'cert_test_ledger')
        ..grantConsumable('hint_token', 3)
        ..grantPermanent('remove_ads');
      var wallMs = 1000000;
      final trustedClock = TrustedClockService(
        sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: wallMs),
      );
      trustedClock.nowMsTrusted();
      wallMs += 2000;
      trustedClock.nowMsTrusted();
      expect(trustedClock.lastJudgement, ClockJudgement.normal);

      final cert = EconomyCertificate.issue(
        wallet: wallet,
        secret: _secret,
        ledger: ledger,
        ledgerConsumableSkus: const {'hint_token'},
        ledgerPermanentSkus: const {'remove_ads'},
        trustedClock: trustedClock,
      );

      final result = EconomyCertificate.verify(cert, _secret);

      expect(result.status, EconomyCertificateStatus.valid);
      expect(result.isValid, isTrue);
      expect(result.balances, {'gems': 100, 'coins': 5000});
      expect(result.clockJudgement, ClockJudgement.normal);
      expect(cert['ledger'], {
        'consumables': {'hint_token': 3},
        'permanents': ['remove_ads'],
      });
    });

    test(
      'không truyền ledger/trustedClock -> vẫn issue+verify hợp lệ, '
      'clockJudgement null',
      () async {
        final wallet = await _walletWith({'gems': 10});

        final cert = EconomyCertificate.issue(
          wallet: wallet,
          secret: _secret,
        );
        final result = EconomyCertificate.verify(cert, _secret);

        expect(result.status, EconomyCertificateStatus.valid);
        expect(result.balances, {'gems': 10});
        expect(result.clockJudgement, isNull);
        expect(cert.containsKey('ledger'), isFalse);
      },
    );
  });

  group('EconomyCertificate.verify: chỉ tamper (save bị chỉnh sửa)', () {
    test('cert bị sửa balance sau khi ký -> status=tampered, balances null', () async {
      final wallet = await _walletWith({'gems': 100});
      final cert = EconomyCertificate.issue(wallet: wallet, secret: _secret);
      final tampered = {...cert, 'balances': {'gems': 999999}};

      final result = EconomyCertificate.verify(tampered, _secret);

      expect(result.status, EconomyCertificateStatus.tampered);
      expect(result.isValid, isFalse);
      expect(result.balances, isNull);
    });

    test('verify với sai secret -> status=tampered', () async {
      final wallet = await _walletWith({'gems': 100});
      final cert = EconomyCertificate.issue(wallet: wallet, secret: _secret);

      final result = EconomyCertificate.verify(cert, 'wrong-secret');

      expect(result.status, EconomyCertificateStatus.tampered);
    });

    test('cert thiếu checksum hoàn toàn -> status=tampered, không throw', () {
      final result = EconomyCertificate.verify({'balances': {}}, _secret);

      expect(result.status, EconomyCertificateStatus.tampered);
    });
  });

  group('EconomyCertificate.verify: chỉ clock nghi ngờ (không tamper)', () {
    test(
      'clockJudgement=rewind tại thời điểm issue -> status=clockSuspicious, '
      'chữ ký vẫn hợp lệ nên balances vẫn đọc được',
      () async {
        final wallet = await _walletWith({'gems': 100});
        var wallMs = 1000000;
        var monotonicMs = 1000000;
        final trustedClock = TrustedClockService(
          sampleNow: () {
            monotonicMs += 1000; // advances normally, real elapsed time.
            return ClockSample(wallMs: wallMs, monotonicMs: monotonicMs);
          },
        );
        trustedClock.nowMsTrusted();
        wallMs -= 60000; // lùi 1 phút, monotonic vẫn tiến -> rewind thật.
        trustedClock.nowMsTrusted();
        expect(trustedClock.lastJudgement, ClockJudgement.rewind);

        final cert = EconomyCertificate.issue(
          wallet: wallet,
          secret: _secret,
          trustedClock: trustedClock,
        );
        final result = EconomyCertificate.verify(cert, _secret);

        expect(result.status, EconomyCertificateStatus.clockSuspicious);
        expect(result.balances, {'gems': 100});
        expect(result.clockJudgement, ClockJudgement.rewind);
      },
    );

    test(
      'clockJudgement=suspiciousForwardJump -> status=clockSuspicious',
      () async {
        final wallet = await _walletWith({'gems': 1});
        var wallMs = 1000000;
        var monotonicMs = 1000000;
        final trustedClock = TrustedClockService(
          sampleNow: () {
            monotonicMs += 1000;
            return ClockSample(wallMs: wallMs, monotonicMs: monotonicMs);
          },
        );
        trustedClock.nowMsTrusted();
        wallMs += const Duration(hours: 3).inMilliseconds; // nhảy xa >1h,
        // monotonic chỉ tiến +1s -> drift lớn -> suspiciousForwardJump.
        trustedClock.nowMsTrusted();
        expect(trustedClock.lastJudgement, ClockJudgement.suspiciousForwardJump);

        final cert = EconomyCertificate.issue(
          wallet: wallet,
          secret: _secret,
          trustedClock: trustedClock,
        );

        expect(
          EconomyCertificate.verify(cert, _secret).status,
          EconomyCertificateStatus.clockSuspicious,
        );
      },
    );
  });

  group('EconomyCertificate.verify: cả tamper VÀ clock nghi ngờ cùng lúc', () {
    test(
      'tamper LUÔN ưu tiên báo cáo trước — 1 payload đã mất tin cậy thì '
      'clockJudgement bên trong nó cũng không còn ý nghĩa để tin',
      () async {
        final wallet = await _walletWith({'gems': 100});
        var wallMs = 1000000;
        var monotonicMs = 1000000;
        final trustedClock = TrustedClockService(
          sampleNow: () {
            monotonicMs += 1000;
            return ClockSample(wallMs: wallMs, monotonicMs: monotonicMs);
          },
        );
        trustedClock.nowMsTrusted();
        wallMs -= 60000;
        trustedClock.nowMsTrusted();
        expect(trustedClock.lastJudgement, ClockJudgement.rewind);

        final cert = EconomyCertificate.issue(
          wallet: wallet,
          secret: _secret,
          trustedClock: trustedClock,
        );
        // Cert này VỐN ĐÃ có clockJudgement=rewind hợp lệ (chữ ký đúng) —
        // giờ tamper thêm balances lên trên nó.
        final tampered = {...cert, 'balances': {'gems': 999999}};

        final result = EconomyCertificate.verify(tampered, _secret);

        expect(result.status, EconomyCertificateStatus.tampered);
      },
    );
  });
}
