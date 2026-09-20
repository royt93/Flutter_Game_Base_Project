import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

void main() {
  testWidgets('CommonButton bấm vào nút variant primary gọi onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonButton(label: 'Play', onTap: () => tapped = true),
        ),
      ),
    );

    // Dùng byType thay vì find.text vì StrokeText vẽ 2 lớp Text chồng nhau
    // (stroke + fill) cho cùng 1 label -> find.text sẽ ambiguous.
    await tester.tap(find.byType(CommonButton));
    await tester.pump();

    expect(tapped, true);
  });

  testWidgets(
    'CommonButton pill chiều cao vừa phải, không quá cao so với text bên trong',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: CommonButton(label: 'Play', onTap: () {}),
            ),
          ),
        ),
      );

      // Trước đây padding dọc 16 mỗi bên khiến nút cao 63px cho text 19sp —
      // quá dày so với quy ước nút mobile thường (~44-52px). Giờ phải rõ
      // ràng thấp hơn hẳn, không chỉ nhích nhẹ.
      final height = tester.getSize(find.byType(CommonButton)).height;
      expect(height, lessThan(52));
    },
  );

  testWidgets(
    'CommonButton pill có padding ngang thật (label không dí sát viền bo tròn)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(label: 'Scenario: force', onTap: () {}),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CommonButton),
          matching: find.byType(Container),
        ),
      );
      final padding = container.padding as EdgeInsets;
      expect(
        padding.horizontal,
        greaterThan(0),
        reason: 'thiếu padding ngang khiến label dí sát/tràn ra mép nút',
      );
    },
  );

  for (final variant in CommonButtonVariant.values) {
    testWidgets('CommonButton render variant $variant không throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(
              label: variant == CommonButtonVariant.icon ? null : 'Label',
              icon: variant == CommonButtonVariant.icon ? Icons.settings : null,
              variant: variant,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('CommonButton onTap == null thì bị disable, tap không throw', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: CommonButton(label: 'Disabled', onTap: null)),
      ),
    );

    final semantics = tester.getSemantics(find.byType(CommonButton));
    expect(semantics.flagsCollection.isEnabled.toBoolOrNull(), false);

    await tester.tap(find.byType(CommonButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('CommonButton semanticLabel tuỳ chỉnh được ưu tiên cao nhất', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // Variant secondary vẽ label bằng 1 Text thường (không phải StrokeText 2
    // lớp) nên semantics label dễ assert hơn.
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonButton(
            label: 'Play',
            semanticLabel: 'Start the game',
            variant: CommonButtonVariant.secondary,
            onTap: () {},
          ),
        ),
      ),
    );

    final label = tester.getSemantics(find.byType(CommonButton)).label;
    // semanticLabel phải là dòng đầu (ưu tiên cao nhất trong fallback chain),
    // bất kể child Text('Play') có bị merge vào cùng node semantics hay không.
    expect(label.split('\n').first, 'Start the game');
    handle.dispose();
  });

  testWidgets('CommonButton không có semanticLabel thì fallback dùng label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonButton(
            label: 'Play',
            variant: CommonButtonVariant.secondary,
            onTap: () {},
          ),
        ),
      ),
    );

    final label = tester.getSemantics(find.byType(CommonButton)).label;
    expect(label.split('\n').first, 'Play');
    handle.dispose();
  });

  testWidgets(
    'CommonButton icon variant, không label/semanticLabel thì fallback dùng icon.toString()',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(
              icon: Icons.settings,
              variant: CommonButtonVariant.icon,
              onTap: () {},
            ),
          ),
        ),
      );

      final label = tester.getSemantics(find.byType(CommonButton)).label;
      expect(label, Icons.settings.toString());
      handle.dispose();
    },
  );

  group('IDEA-53: loading state', () {
    testWidgets('loading: true chặn tap, onTap không được gọi', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(
              label: 'Buy',
              loading: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CommonButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('loading: true hiện CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(label: 'Buy', loading: true, onTap: () {}),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'loading: true, variant icon vẫn hiện CircularProgressIndicator, giữ nguyên kích thước nút',
      (tester) async {
        Future<Size> sizeOf(bool loading) async {
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Center(
                  child: KeyedSubtree(
                    key: key,
                    child: CommonButton(
                      icon: Icons.settings,
                      variant: CommonButtonVariant.icon,
                      loading: loading,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          if (loading) {
            expect(find.byType(CircularProgressIndicator), findsOneWidget);
          }
          return tester.getSize(find.byKey(key));
        }

        final normalSize = await sizeOf(false);
        final loadingSize = await sizeOf(true);
        expect(loadingSize, normalSize);
      },
    );

    testWidgets(
      'loading: true không làm đổi kích thước tổng thể của pill so với loading: false',
      (tester) async {
        Future<Size> sizeOf(bool loading) async {
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Center(
                  child: KeyedSubtree(
                    key: key,
                    child: CommonButton(
                      // Label ngắn, không cần FittedBox scale-down ở width
                      // mặc định — test này verify loading không đổi kích
                      // thước OUTER pill, không phải hành vi scale-down
                      // (nhạy với padding ngang của Container).
                      label: 'Buy',
                      loading: loading,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          return tester.getSize(find.byKey(key));
        }

        final normalSize = await sizeOf(false);
        final loadingSize = await sizeOf(true);
        // Dung sai 1 logical pixel: nội dung pill vẫn được layout nguyên
        // vẹn (chỉ ẩn qua Opacity) ở cả 2 trạng thái, nên kích thước thực
        // tế ổn định — chênh lệch dưới 1px là làm tròn sub-pixel của
        // TextPainter/Stack, không phải nút đổi kích thước thấy được.
        expect(loadingSize.width, closeTo(normalSize.width, 1.0));
        expect(loadingSize.height, closeTo(normalSize.height, 1.0));
      },
    );

    testWidgets(
      'loading: false (mặc định) hành vi y hệt trước đây, không hiện spinner',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: CommonButton(label: 'Play', onTap: () => tapped = true),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.byType(CommonButton));
        expect(tapped, isTrue);
      },
    );

    testWidgets('Semantics: enabled == false khi loading dù onTap khác null', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(label: 'Buy', loading: true, onTap: () {}),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(CommonButton));
      expect(semantics.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      handle.dispose();
    });

    testWidgets('Semantics: label vẫn giữ ý nghĩa, không rỗng, khi loading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(label: 'Buy', loading: true, onTap: () {}),
          ),
        ),
      );

      final label = tester.getSemantics(find.byType(CommonButton)).label;
      expect(label, isNotEmpty);
      expect(label, contains('Buy'));
      handle.dispose();
    });
  });
}
