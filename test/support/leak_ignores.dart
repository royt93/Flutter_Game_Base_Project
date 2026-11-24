import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// For a test where a widget's `initState` is MEANT to throw (constructor
/// validation, ENH-85): the framework keeps the half-built Element and State
/// without ever disposing them. That is Flutter's behaviour, not a leak in the
/// widget, so those classes (plus the State's own class, passed in) are ignored
/// for that one test only. Anything else the test leaks still fails it.
LeakTesting ignoringFailedInitState(String stateClass) =>
    LeakTesting.settings.withIgnored(
      classes: [
        'StatefulElement',
        'SingleChildRenderObjectElement',
        'RenderSemanticsAnnotations',
        'RenderConstrainedBox',
        stateClass,
      ],
    );

/// Flame (1.38) gives `Transform2D`/`NotifyingVector2` (and the game's lifecycle
/// notifier) ChangeNotifier bases but no way for a caller to dispose them, so a
/// `FlameGame` built in a test always "leaks" them. That is Flame's, not the
/// kit's: ignore exactly those classes, nothing else.
LeakTesting get ignoringFlameInternals => LeakTesting.settings.withIgnored(
  classes: ['NotifyingVector2', 'Transform2D', 'ValueNotifier<bool>'],
);
