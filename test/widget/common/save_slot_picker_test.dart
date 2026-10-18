import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

const _slots = [
  SaveSlotMeta(
    id: 'slot_1',
    displayName: 'Campaign One',
    createdAtMs: 1000,
    lastPlayedAtMs: 2000,
  ),
  SaveSlotMeta(
    id: 'slot_2',
    displayName: 'Campaign Two',
    createdAtMs: 1000,
    lastPlayedAtMs: 3000,
  ),
];

Widget _subject({
  List<SaveSlotMeta> slots = _slots,
  String? activeSlotId = 'slot_1',
  ValueChanged<String>? onSelect,
  VoidCallback? onCreate,
  ValueChanged<String>? onDelete,
  int? maxSlots,
  bool loading = false,
  String? errorMessage,
  Future<void> Function()? onRetry,
  bool disableAnimations = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SaveSlotPicker(
        slots: slots,
        activeSlotId: activeSlotId,
        onSelect: onSelect ?? (_) {},
        onCreate: onCreate,
        onDelete: onDelete,
        maxSlots: maxSlots,
        loading: loading,
        errorMessage: errorMessage,
        onRetry: onRetry,
      ),
    ),
  ),
);

void main() {
  group('SaveSlotPicker validation', () {
    test('rejects invalid maxSlots', () {
      expect(
        () => SaveSlotPicker(slots: _slots, onSelect: (_) {}, maxSlots: 0),
        throwsArgumentError,
      );
    });

    test('rejects duplicate ids, empty id/name, and negative timestamps', () {
      SaveSlotMeta slot({
        String id = 'slot',
        String name = 'Name',
        int created = 1,
        int played = 1,
      }) => SaveSlotMeta(
        id: id,
        displayName: name,
        createdAtMs: created,
        lastPlayedAtMs: played,
      );

      void expectInvalid(List<SaveSlotMeta> slots) {
        expect(
          () => SaveSlotPicker(slots: slots, onSelect: (_) {}),
          throwsArgumentError,
        );
      }

      expectInvalid([slot(), slot()]);
      expectInvalid([slot(id: ' ')]);
      expectInvalid([slot(name: ' ')]);
      expectInvalid([slot(created: -1)]);
      expectInvalid([slot(played: -1)]);
    });
  });

  group('SaveSlotPicker UI', () {
    testWidgets('shows active row and selects inactive slot by id', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(_subject(onSelect: (id) => selected = id));

      expect(find.text('Campaign One'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('saveSlotSelectBtn_slot_1')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('saveSlotSelectBtn_slot_2')));
      expect(selected, 'slot_2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('creates when under max; disables at limit', (tester) async {
      var created = 0;
      await tester.pumpWidget(_subject(maxSlots: 3, onCreate: () => created++));
      await tester.tap(find.byKey(const ValueKey('saveSlotCreateBtn')));
      expect(created, 1);

      await tester.pumpWidget(_subject(maxSlots: 2, onCreate: () => created++));
      final button = tester.widget<CommonButton>(
        find.byKey(const ValueKey('saveSlotCreateBtn')),
      );
      expect(button.onTap, isNull);
    });

    testWidgets('delete cancel preserves slot; confirm calls id once', (
      tester,
    ) async {
      final deleted = <String>[];
      await tester.pumpWidget(_subject(onDelete: deleted.add));

      await tester.tap(find.byKey(const ValueKey('saveSlotDeleteBtn_slot_2')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Delete Save Slot?'), findsOneWidget);
      final cancel = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is NeonDialogButton && widget.action.label == 'Cancel',
        ),
      );
      cancel.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(deleted, isEmpty);

      await tester.tap(find.byKey(const ValueKey('saveSlotDeleteBtn_slot_2')));
      await tester.pump(const Duration(milliseconds: 300));
      final confirm = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is NeonDialogButton && widget.action.label == 'Delete',
        ),
      );
      confirm.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      expect(deleted, ['slot_2']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows loading, error with retry, and empty states', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      var retried = false;
      await tester.pumpWidget(
        _subject(
          errorMessage: 'Storage unavailable',
          onRetry: () async {
            retried = true;
          },
        ),
      );
      expect(find.text('Storage unavailable'), findsOneWidget);
      await tester.tap(find.byType(AsyncCommonButton));
      await tester.pump();
      expect(retried, isTrue);

      await tester.pumpWidget(_subject(slots: const []));
      expect(find.text('No save slots yet'), findsOneWidget);
    });

    testWidgets('exposes picker semantics and builds under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(disableAnimations: true));

      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('saveSlotPickerSemantics')),
      );
      expect(semantics.properties.label, contains('2 slots available'));
      expect(semantics.properties.label, contains('slot_1'));
      expect(find.text('Campaign One'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismisses delete confirmation when widget unmounts', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(onDelete: (_) {}));
      await tester.tap(find.byKey(const ValueKey('saveSlotDeleteBtn_slot_2')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
