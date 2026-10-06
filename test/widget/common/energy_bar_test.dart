import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:roy_casual_kit/presentation/widgets/common/energy_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

class _SnapshotEnergyService extends EnergyService {
  _SnapshotEnergyService({required super.maxEnergy, required this.count});
  int count;

  @override
  int get currentEnergy => count;

  @override
  Duration get timeUntilNextEnergy => Duration.zero;

  @override
  bool get hasInfiniteLives => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('renders maxEnergy pips, currentEnergy of them filled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 3,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration(minutes: 12),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
  });

  testWidgets('shows ∞ and no countdown when hasInfiniteLives', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 5,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration.zero,
          hasInfiniteLives: true,
        ),
      ),
    );

    expect(find.text('∞'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('no countdown text when energy is already full', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 5,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration.zero,
        ),
      ),
    );

    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('shows a countdown that ticks down over a couple of seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 3,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration(minutes: 1, seconds: 5),
        ),
      ),
    );

    expect(find.text('01:05'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('01:03'), findsOneWidget);
  });

  testWidgets('reduced motion still shows the countdown text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(
          const EnergyBar(
            currentEnergy: 3,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration(seconds: 42),
          ),
        ),
      ),
    );

    expect(find.text('00:42'), findsOneWidget);
  });

  group('ENH-42: direction/icon/color customization', () {
    testWidgets('mặc định (không truyền gì mới) vẫn Column, icon/màu như cũ', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const EnergyBar(
            currentEnergy: 2,
            maxEnergy: 3,
            timeUntilNextEnergy: Duration(seconds: 30),
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(1));
    });

    testWidgets('direction: Axis.horizontal render Row thay vì Column', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const EnergyBar(
            currentEnergy: 2,
            maxEnergy: 3,
            timeUntilNextEnergy: Duration(seconds: 30),
            direction: Axis.horizontal,
          ),
        ),
      );

      expect(find.byType(Row), findsWidgets);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets(
      'icon/emptyIcon/color tuỳ chỉnh hiển thị đúng thay vì mặc định',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const EnergyBar(
              currentEnergy: 1,
              maxEnergy: 2,
              timeUntilNextEnergy: Duration.zero,
              icon: Icons.bolt,
              emptyIcon: Icons.bolt_outlined,
              color: Colors.purple,
            ),
          ),
        );

        expect(find.byIcon(Icons.bolt), findsOneWidget);
        expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.favorite_border), findsNothing);

        final filledIcon = tester.widget<Icon>(find.byIcon(Icons.bolt));
        expect(filledIcon.color, Colors.purple);
      },
    );
  });

  group('ENH-37: Semantics', () {
    testWidgets('label khớp đúng "Energy: N/M" ở 2 trạng thái khác nhau', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const EnergyBar(
            currentEnergy: 3,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration(seconds: 30),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(EnergyBar)).label,
        contains('Energy: 3/5'),
      );

      await tester.pumpWidget(
        _wrap(
          const EnergyBar(
            currentEnergy: 5,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration.zero,
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(EnergyBar)).label, 'Energy: 5/5');
      handle.dispose();
    });

    testWidgets('hasInfiniteLives → label "Energy: infinite"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const EnergyBar(
            currentEnergy: 5,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration.zero,
            hasInfiniteLives: true,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(EnergyBar)).label,
        'Energy: infinite',
      );
      handle.dispose();
    });

    testWidgets('semanticLabel tuỳ chỉnh ghi đè đúng label mặc định', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const EnergyBar(
            currentEnergy: 3,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration(seconds: 30),
            semanticLabel: 'Lives: 3',
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(EnergyBar)).label, 'Lives: 3');
      handle.dispose();
    });
  });

  group('BUG-95: ReactiveEnergyBar', () {
    late StorageService store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
      Get.put(store, permanent: true);
    });

    testWidgets(
      'tự cập nhật pip khi EnergyService refill ngầm, không cần caller '
      'truyền snapshot mới',
      (tester) async {
        final service = Get.put(
          EnergyService(
            maxEnergy: 3,
            refillInterval: const Duration(seconds: 5),
          ),
          permanent: true,
        );
        expect(service.consumeEnergy(2), isTrue);
        expect(service.currentEnergy, 1);

        await tester.pumpWidget(
          _wrap(const ReactiveEnergyBar(pollInterval: Duration(seconds: 1))),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester.getSemantics(find.byType(EnergyBar)).label,
          contains('1/3'),
        );

        setDebugTimeOffsetMs(const Duration(seconds: 6).inMilliseconds);
        await tester.pump(const Duration(seconds: 1));

        expect(
          tester.getSemantics(find.byType(EnergyBar)).label,
          contains('2/3'),
        );

        setDebugTimeOffsetMs(0);
      },
    );

    testWidgets('không có EnergyService đăng ký → không throw, ẩn', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ReactiveEnergyBar()));
      await tester.pump();

      expect(find.byType(EnergyBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('didUpdateWidget cập nhật khi swap energyService hoặc pollInterval', (
      tester,
    ) async {
      final s1 = _SnapshotEnergyService(maxEnergy: 4, count: 2);
      final s2 = _SnapshotEnergyService(maxEnergy: 6, count: 5);

      await tester.pumpWidget(_wrap(ReactiveEnergyBar(
        energyService: s1,
        pollInterval: const Duration(seconds: 2),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));

      // Swap sang service mới + pollInterval mới
      await tester.pumpWidget(_wrap(ReactiveEnergyBar(
        energyService: s2,
        pollInterval: Duration.zero,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.favorite), findsNWidgets(5));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(1));
      s2.count = 1;
      await tester.pump(const Duration(seconds: 3));
      expect(find.byIcon(Icons.favorite), findsNWidgets(5));

      await tester.pumpWidget(_wrap(ReactiveEnergyBar(
        energyService: s2,
        pollInterval: const Duration(milliseconds: 200),
      )));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      s2.count = 4;
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.favorite), findsNWidgets(4));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('didUpdateWidget trên EnergyBar khởi động lại timer đếm lùi', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const EnergyBar(
        currentEnergy: 1,
        maxEnergy: 2,
        timeUntilNextEnergy: Duration(seconds: 5),
      )));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:03'), findsOneWidget);

      // Cập nhật mốc mới
      await tester.pumpWidget(_wrap(const EnergyBar(
        currentEnergy: 1,
        maxEnergy: 2,
        timeUntilNextEnergy: Duration(seconds: 10),
      )));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:09'), findsOneWidget);
    });
  });
}
