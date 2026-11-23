import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/undo_stack.dart';

void main() {
  group('UndoStack (FEAT-216)', () {
    test('constructor rejects capacity <= 0', () {
      expect(() => UndoStack<int>(capacity: 0), throwsArgumentError);
      expect(() => UndoStack<int>(capacity: -3), throwsArgumentError);
      expect(UndoStack<int>(capacity: 1).capacity, 1);
    });

    test('starts empty: nothing to undo or redo, no throw', () {
      final s = UndoStack<int>(capacity: 3);
      expect(s.canUndo, isFalse);
      expect(s.canRedo, isFalse);
      expect(s.undo(), isNull);
      expect(s.redo(), isNull);
      expect(s.current, isNull);
    });

    test('push then undo returns the previous state, redo returns it back', () {
      final s = UndoStack<int>(capacity: 5)
        ..push(1)
        ..push(2)
        ..push(3);
      expect(s.current, 3);
      expect(s.undo(), 2);
      expect(s.undo(), 1);
      expect(s.canUndo, isFalse);
      expect(s.undo(), isNull);
      expect(s.redo(), 2);
      expect(s.redo(), 3);
      expect(s.canRedo, isFalse);
      expect(s.redo(), isNull);
    });

    test('a push after undo drops the redo branch', () {
      final s = UndoStack<int>(capacity: 5)
        ..push(1)
        ..push(2)
        ..push(3);
      s.undo();
      s.undo();
      expect(s.canRedo, isTrue);
      s.push(9);
      expect(s.canRedo, isFalse);
      expect(s.current, 9);
      expect(s.undo(), 1);
    });

    test('exceeding capacity drops the OLDEST state', () {
      final s = UndoStack<int>(capacity: 3)
        ..push(1)
        ..push(2)
        ..push(3)
        ..push(4);
      expect(s.length, 3);
      expect(s.undo(), 3);
      expect(s.undo(), 2);
      expect(s.undo(), isNull, reason: '1 was dropped');
    });

    test('capacity 1 keeps only the latest state and cannot undo', () {
      final s = UndoStack<int>(capacity: 1)
        ..push(1)
        ..push(2);
      expect(s.current, 2);
      expect(s.canUndo, isFalse);
    });

    test('clear empties both directions', () {
      final s = UndoStack<int>(capacity: 4)
        ..push(1)
        ..push(2);
      s.undo();
      s.clear();
      expect(s.length, 0);
      expect(s.canUndo, isFalse);
      expect(s.canRedo, isFalse);
      expect(s.current, isNull);
    });

    test('many random operations never break the invariants', () {
      final s = UndoStack<int>(capacity: 7);
      var seed = 12345;
      int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      for (var i = 0; i < 5000; i++) {
        switch (next() % 3) {
          case 0:
            s.push(i);
          case 1:
            s.undo();
          default:
            s.redo();
        }
        expect(s.length, lessThanOrEqualTo(7));
        expect(s.length, greaterThanOrEqualTo(0));
        if (s.length > 0) expect(s.current, isNotNull);
        if (!s.canUndo && !s.canRedo) expect(s.length, lessThanOrEqualTo(1));
      }
    });
  });
}
