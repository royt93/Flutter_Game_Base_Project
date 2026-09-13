import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../core/utils/clamped_clock.dart';
import '../../core/utils/trusted_clock.dart';
import 'common/common_button.dart';

/// Hidden debug/QA overlay — a small long-press trigger in a screen corner
/// that opens a panel with 2 tabs: a read-only dump of live internal
/// package state (every `StorageService` key/value, audio mute, current
/// locale, clock diagnostics), and a Playground tab (IDEA-39) that lets a
/// QA tester/designer live-preview a `CommonButton` with adjustable
/// label/variant/color right on-device — no rebuild needed to answer
/// "what would this button look like in red with this label?".
///
/// Gated exactly like [dlog] (`lib/core/debug_log.dart`) — `kDebugMode ||
/// kProfileMode` — so a QA build (which is typically a profile build, not a
/// debug build) still gets it, while a release build never builds the
/// trigger or panel at all (this widget degrades to exactly [child]).
///
/// Usage — wrap your app's root widget:
/// ```dart
/// DebugQaOverlay(child: MaterialApp(...));
/// ```
class DebugQaOverlay extends StatefulWidget {
  const DebugQaOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<DebugQaOverlay> createState() => _DebugQaOverlayState();
}

class _DebugQaOverlayState extends State<DebugQaOverlay> {
  bool _open = false;
  Timer? _refreshTimer;
  int _tab = 0;

  // IDEA-39 Playground state — same sample colors/label already used by
  // `example/lib/screens/widget_showcase_screen.dart`'s own CommonButton
  // demo, rather than inventing a new palette just for this panel.
  CommonButtonVariant _playgroundVariant = CommonButtonVariant.primary;
  Color _playgroundColor = NeonTheme.cyan;
  late final TextEditingController _playgroundLabelController =
      TextEditingController(text: 'Preview');

  void _toggle() {
    setState(() => _open = !_open);
    _refreshTimer?.cancel();
    _refreshTimer = _open
        ? Timer.periodic(
            const Duration(milliseconds: 500),
            (_) => setState(() {}),
          )
        : null;
  }

  void _setTab(int tab) => setState(() => _tab = tab);

  void _setPlaygroundVariant(CommonButtonVariant variant) =>
      setState(() => _playgroundVariant = variant);

  void _setPlaygroundColor(Color color) =>
      setState(() => _playgroundColor = color);

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _playgroundLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_open)
          _Panel(
            onClose: _toggle,
            tab: _tab,
            onTabChanged: _setTab,
            playgroundVariant: _playgroundVariant,
            playgroundColor: _playgroundColor,
            playgroundLabelController: _playgroundLabelController,
            onPlaygroundVariantChanged: _setPlaygroundVariant,
            onPlaygroundColorChanged: _setPlaygroundColor,
          ),
        // Kept on top of the panel (rather than under it) so long-pressing
        // the corner again always closes the panel too, not just tapping
        // outside it.
        Positioned(
          top: 0,
          right: 0,
          width: 48,
          height: 48,
          child: GestureDetector(
            key: const Key('debugQaOverlayTrigger'),
            behavior: HitTestBehavior.opaque,
            onLongPress: _toggle,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
    required this.playgroundVariant,
    required this.playgroundColor,
    required this.playgroundLabelController,
    required this.onPlaygroundVariantChanged,
    required this.onPlaygroundColorChanged,
  });

  final VoidCallback onClose;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final CommonButtonVariant playgroundVariant;
  final Color playgroundColor;
  final TextEditingController playgroundLabelController;
  final ValueChanged<CommonButtonVariant> onPlaygroundVariantChanged;
  final ValueChanged<Color> onPlaygroundColorChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose, // tap outside the panel dismisses it
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps inside the panel
              // IDEA-39: the Playground tab's ChoiceChip/TextField (and
              // any InkWell-based widget) need a Material ancestor —
              // this panel is dropped directly into the app's root Stack
              // via DebugQaOverlay, outside any Scaffold/Material.
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 520),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Debug QA',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              label: 'State',
                              selected: tab == 0,
                              onTap: () => onTabChanged(0),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              label: 'Playground',
                              selected: tab == 1,
                              onTap: () => onTabChanged(1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: tab == 0
                            ? const _StateTab()
                            : _PlaygroundTab(
                                variant: playgroundVariant,
                                color: playgroundColor,
                                labelController: playgroundLabelController,
                                onVariantChanged: onPlaygroundVariantChanged,
                                onColorChanged: onPlaygroundColorChanged,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A plain GestureDetector, not InkWell — this panel isn't inside a
    // Material ancestor (it's dropped directly into the app's root Stack
    // via DebugQaOverlay), and InkWell asserts one must exist.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? NeonTheme.cyan : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? NeonTheme.cyan : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _StateTab extends StatelessWidget {
  const _StateTab();

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.maybe?.exportAll() ?? const {};
    final audioMuted = AudioManager.maybe?.muted.value;
    final locale = LocaleService.maybe?.current.value;
    // IDEA-40: sampled fresh every panel rebuild (same 500ms auto-refresh
    // as the rest of this panel) — this is what a device smoke test
    // changing the REAL system clock via Settings watches change live,
    // since every other test of this class injects a fake sample instead
    // of touching the actual OS clock.
    int? trustedNowMs;
    ClockJudgement? trustedJudgement;
    if (StorageService.maybe != null) {
      final trustedClock = TrustedClockService();
      trustedNowMs = trustedClock.nowMsTrusted();
      trustedJudgement = trustedClock.lastJudgement;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audio muted: ${audioMuted?.toString() ?? "not registered"}'),
          Text('Locale: ${locale?.toString() ?? "not registered"}'),
          Text('Clock rewind blocked: $clockRewindBlockedCount'),
          Text(
            'TrustedClock now: '
            '${trustedNowMs?.toString() ?? "not registered"}',
          ),
          Text(
            'TrustedClock judgement: '
            '${trustedJudgement?.name ?? "n/a (first sample)"}',
          ),
          const Divider(),
          for (final entry in storage.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// IDEA-39: live `CommonButton` playground — a designer/QA can try a
/// different label/variant/color right on-device, without an engineer
/// changing code and rebuilding. Deliberately scoped to 1 widget
/// (`CommonButton`, the kit's most commonly reused one) rather than every
/// widget in `common/` — see this task's `## Quyết định` for why.
class _PlaygroundTab extends StatelessWidget {
  const _PlaygroundTab({
    required this.variant,
    required this.color,
    required this.labelController,
    required this.onVariantChanged,
    required this.onColorChanged,
  });

  final CommonButtonVariant variant;
  final Color color;
  final TextEditingController labelController;
  final ValueChanged<CommonButtonVariant> onVariantChanged;
  final ValueChanged<Color> onColorChanged;

  // Same sample palette `widget_showcase_screen.dart`'s own demos already
  // draw from — not a new set of colors invented just for this panel.
  static final _swatches = [
    NeonTheme.cyan,
    NeonTheme.magenta,
    NeonTheme.gold,
    NeonTheme.lime,
    NeonTheme.red,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CommonButton',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: labelController,
              builder: (context, value, _) => CommonButton(
                label: value.text.isEmpty ? ' ' : value.text,
                variant: variant,
                color: color,
                onTap: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Label'),
          TextField(
            key: const Key('debugQaPlaygroundLabelField'),
            controller: labelController,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('Variant'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final v in CommonButtonVariant.values.where(
                (v) => v != CommonButtonVariant.icon,
              ))
                ChoiceChip(
                  key: Key('debugQaPlaygroundVariant_${v.name}'),
                  label: Text(v.name),
                  selected: variant == v,
                  onSelected: (_) => onVariantChanged(v),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Color'),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final swatch in _swatches)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('debugQaPlaygroundColor_${swatch.toARGB32()}'),
                    onTap: () => onColorChanged(swatch),
                    child: AnimatedContainer(
                      duration: NeonTheme.reducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: color == swatch ? 32 : 24,
                      height: color == swatch ? 32 : 24,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: color == swatch
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
