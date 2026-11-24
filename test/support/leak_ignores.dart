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
