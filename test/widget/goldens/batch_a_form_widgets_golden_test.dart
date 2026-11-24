import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/async_common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/avatar_frame.dart';
import 'package:roy_casual_kit/presentation/widgets/common/badge_dot.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_radio_group.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_search_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_slider.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_text_field.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/cooldown_countdown_chip.dart';
import 'package:roy_casual_kit/presentation/widgets/common/countdown_chip.dart';
import 'package:roy_casual_kit/presentation/widgets/common/expandable_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/hold_to_confirm_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/icon_badge_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/list_tile_row.dart';
import 'package:roy_casual_kit/presentation/widgets/common/panel_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/section_header.dart';
import 'package:roy_casual_kit/presentation/widgets/common/segmented_tab_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/sound_toggle_fab.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_rating.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toggle_switch.dart';

import '../../support/golden_matrix.dart';
import '../../support/owned_storage.dart';
import 'golden_test_support.dart';

/// ENH-118 (batch A): static input/form widgets. One golden per widget, with
/// the interesting states stacked in one frame, rendered through the shared
/// matrix (baseline, dark, locale-vi, rtl, text scale 1.3 and 2.0, reduced
/// motion). Everything here is deterministic: no real clock is read after the
/// first frame, nothing is random, no animation is left running.
///
/// Not covered on purpose: `BadgeDot` pulse/radar animation (batch F).
void main() {
  final previous = installGoldenTolerance('batch_a_form_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget stack(List<Widget> children) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 360),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    ),
  );

  Future<void> golden(
    WidgetTester tester,
    String name,
    List<Widget> Function() states, {
    List<GoldenMatrixCase>? matrix,
  }) async {
    await runGoldenMatrix(
      tester,
      (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: stack(states()),
      ),
      goldenBaseName: name,
      matrix: matrix,
    );
  }

  // The matrix's locale-vi case wraps the tree in `Localizations.override(vi)`,
  // and Flutter ships MaterialLocalizations for `en` only here, so a TextField
  // (CandyTextField, CandySearchBar) has none to find and asserts. Widgets with
  // a text field run every case except that one.
  final withoutLocaleVi = [
    for (final c in defaultGoldenMatrix())
      if (c.name != 'locale-vi') c,
  ];

  testWidgets('AsyncCommonButton idle, disabled, wide', (tester) async {
    await golden(
      tester,
      'asynccommonbutton_states',
      () => [
        AsyncCommonButton(label: 'Save', onPressed: () async {}),
        const AsyncCommonButton(label: 'Disabled', onPressed: null),
        AsyncCommonButton(
          label: 'Danger',
          variant: CommonButtonVariant.danger,
          onPressed: () async {},
        ),
      ],
    );
  });

  testWidgets('CandyRadioGroup and CandyCheckboxTile', (tester) async {
    await golden(
      tester,
      'candyradiogroup_states',
      () => [
        CandyRadioGroup<int>(
          options: const [
            CandyRadioOption(value: 1, label: 'One', subtitle: 'first option'),
            CandyRadioOption(value: 2, label: 'Two'),
            CandyRadioOption(value: 3, label: 'Three'),
          ],
          value: 2,
          onChanged: (_) {},
        ),
        CandyCheckboxTile(
          label: 'Remember me',
          subtitle: 'Stay signed in',
          value: true,
          onChanged: (_) {},
        ),
        CandyCheckboxTile(label: 'Newsletter', value: false, onChanged: (_) {}),
        const CandyCheckboxTile(
          label: 'Disabled',
          value: true,
          onChanged: null,
        ),
      ],
    );
  });

  testWidgets('CandySearchBar empty, with text, and FilterChipRow', (
    tester,
  ) async {
    final empty = TextEditingController();
    final filled = TextEditingController(text: 'cats');
    addTearDown(empty.dispose);
    addTearDown(filled.dispose);
    await golden(
      tester,
      'candysearchbar_states',
      matrix: withoutLocaleVi,
      () => [
        CandySearchBar(controller: empty, onChanged: (_) {}),
        CandySearchBar(controller: filled, onChanged: (_) {}),
        FilterChipRow<String>(
          filters: const [
            CandyFilter(value: 'all', label: 'All'),
            CandyFilter(value: 'new', label: 'New'),
            CandyFilter(value: 'top', label: 'Top rated'),
          ],
          selectedValues: const {'all', 'top'},
          onChanged: (_) {},
        ),
      ],
    );
  });

  testWidgets('CandySlider enabled, divided, disabled', (tester) async {
    await golden(
      tester,
      'candyslider_states',
      () => [
        CandySlider(value: 0.4, onChanged: (_) {}),
        CandySlider(value: 3, min: 0, max: 5, divisions: 5, onChanged: (_) {}),
        CandySlider(value: 0.7, onChanged: null),
      ],
    );
  });

  testWidgets('CandyTextField hint and filled', (tester) async {
    final empty = TextEditingController();
    final filled = TextEditingController(text: 'Roy');
    final secret = TextEditingController(text: 'secret');
    addTearDown(empty.dispose);
    addTearDown(filled.dispose);
    addTearDown(secret.dispose);
    await golden(
      tester,
      'candytextfield_states',
      matrix: withoutLocaleVi,
      () => [
        CandyTextField(
          controller: empty,
          hintText: 'Player name',
          prefixIcon: Icons.person,
        ),
        CandyTextField(controller: filled, prefixIcon: Icons.person),
        CandyTextField(controller: secret, obscureText: true),
      ],
    );
  });

  testWidgets('CandyToggleSwitch on, off, disabled', (tester) async {
    await golden(
      tester,
      'candytoggleswitch_states',
      () => [
        // Inside a tile, as the Settings screen uses it: the title names the
        // switch for a screen reader.
        CommonListTile(
          title: 'Sound',
          trailing: CandyToggleSwitch(value: true, onChanged: (_) {}),
        ),
        CommonListTile(
          title: 'Dark mode',
          trailing: CandyToggleSwitch(value: false, onChanged: (_) {}),
        ),
        const CommonListTile(
          title: 'Locked option',
          trailing: CandyToggleSwitch(value: true, onChanged: null),
        ),
      ],
    );
  });

  testWidgets('HoldToConfirmButton radial, linear, disabled', (tester) async {
    await golden(
      tester,
      'holdtoconfirmbutton_states',
      () => [
        HoldToConfirmButton(label: 'Hold to delete', onConfirm: () {}),
        HoldToConfirmButton(
          label: 'Hold to reset',
          shape: HoldToConfirmShape.linear,
          onConfirm: () {},
        ),
        HoldToConfirmButton(
          label: 'Locked',
          enabled: false,
          onConfirm: () {},
        ),
      ],
    );
  });

  testWidgets('IconBadgeButton with and without badge', (tester) async {
    await golden(
      tester,
      'iconbadgebutton_states',
      () => [
        Row(
          children: [
            IconBadgeButton(icon: Icons.mail, onTap: () {}),
            const SizedBox(width: 16),
            IconBadgeButton(
              icon: Icons.mail,
              onTap: () {},
              showBadge: true,
              badgeCount: 3,
            ),
            const SizedBox(width: 16),
            IconBadgeButton(
              icon: Icons.notifications,
              onTap: () {},
              showBadge: true,
              badgeCount: 120,
            ),
            const SizedBox(width: 16),
            IconBadgeButton(icon: Icons.chat, onTap: () {}, showBadge: true),
          ],
        ),
      ],
    );
  });

  testWidgets('SegmentedTabBar selected positions', (tester) async {
    await golden(
      tester,
      'segmentedtabbar_states',
      () => [
        SegmentedTabBar(
          labels: const ['Daily', 'Weekly', 'Season'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        SegmentedTabBar(
          labels: const ['Daily', 'Weekly', 'Season'],
          selectedIndex: 2,
          onChanged: (_) {},
        ),
      ],
    );
  });

  testWidgets('CommonListTile variants', (tester) async {
    await golden(
      tester,
      'commonlisttile_states',
      () => [
        CommonListTile(
          title: 'Settings',
          subtitle: 'Sound and language',
          leading: const Icon(Icons.settings),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const CommonListTile(title: 'Plain row'),
        CommonListTile(
          title: 'Outlined row',
          filled: false,
          trailing: const Icon(Icons.check_circle),
          onTap: () {},
        ),
      ],
    );
  });

  testWidgets('SectionHeader with and without trailing', (tester) async {
    await golden(
      tester,
      'sectionheader_states',
      () => const [
        SectionHeader(title: 'Rewards'),
        SectionHeader(title: 'Quests', trailing: Text('See all')),
      ],
    );
  });

  testWidgets('ExpandablePanel collapsed and expanded', (tester) async {
    await golden(
      tester,
      'expandablepanel_states',
      () => const [
        ExpandablePanel(
          header: Text('Collapsed'),
          content: Text('Hidden content'),
        ),
        ExpandablePanel(
          header: Text('Expanded'),
          content: Text('Visible content line one.\nLine two.'),
          isExpanded: true,
          duration: Duration(milliseconds: 1),
        ),
      ],
    );
  });

  testWidgets('StarRating none, partial, full', (tester) async {
    await golden(
      tester,
      'starrating_states',
      () => const [
        StarRating(earned: 0),
        StarRating(earned: 2),
        StarRating(earned: 3),
        StarRating(earned: 4, total: 5, size: 28),
      ],
    );
  });

  for (final muted in [false, true]) {
    testWidgets('SoundToggleFab ${muted ? 'muted' : 'unmuted'}', (tester) async {
      Get.put(await ownedStorage());
      final audio = Get.put(AudioManager(), permanent: true);
      addTearDown(Get.reset);
      // Set BEFORE building: changing an Rx while a frame builds is an error.
      audio.muted.value = muted;
      await golden(
        tester,
        'soundtogglefab_${muted ? 'muted' : 'unmuted'}',
        () => [const Align(alignment: Alignment.centerLeft, child: SoundToggleFab())],
      );
    });
  }

  testWidgets('BadgeDot sizes and colors (static)', (tester) async {
    await golden(
      tester,
      'badgedot_states',
      () => [
        Row(
          children: [
            const BadgeDot(),
            const SizedBox(width: 16),
            const BadgeDot(size: 16),
            const SizedBox(width: 16),
            BadgeDot(size: 20, color: NeonTheme.cyan),
          ],
        ),
      ],
    );
  });

  testWidgets('CountdownChip and CooldownCountdownChip', (tester) async {
    await golden(
      tester,
      'countdownchip_states',
      () => [
        // Stacked, not side by side: two chips in a row overflow a 360dp frame
        // at 2.0x text.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CountdownChip(
            target: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: CooldownCountdownChip(
            remaining: Duration(minutes: 2, seconds: 30),
          ),
        ),
      ],
    );
  });

  testWidgets('PanelCard plain, alt and bordered', (tester) async {
    await golden(
      tester,
      'panelcard_states',
      () => [
        const PanelCard(child: Text('Plain card')),
        const PanelCard(alt: true, child: Text('Alt card')),
        PanelCard(borderColor: NeonTheme.gold, child: const Text('Bordered')),
      ],
    );
  });

  testWidgets('AvatarFrame sizes and colors', (tester) async {
    await golden(
      tester,
      'avatarframe_states',
      () => [
        Row(
          children: [
            const AvatarFrame(child: Icon(Icons.person)),
            const SizedBox(width: 16),
            AvatarFrame(
              size: 48,
              color: NeonTheme.gold,
              ringWidth: 5,
              child: const Icon(Icons.star),
            ),
            const SizedBox(width: 16),
            AvatarFrame(
              size: 80,
              color: NeonTheme.cyan,
              onTap: () {},
              child: const Text('AB'),
            ),
          ],
        ),
      ],
    );
  });
}
