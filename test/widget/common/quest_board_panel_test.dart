import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/progress_bar_stars.dart';
import 'package:roy_casual_kit/presentation/widgets/common/quest_board_panel.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('danh sách rỗng hiển thị empty-state, không crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(QuestBoardPanel(quests: const [], onClaim: (_) {})),
    );

    expect(find.text('Không có nhiệm vụ nào hôm nay.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'quest chưa hoàn thành: hiện đúng label, nút Nhận thưởng bị disable',
    (tester) async {
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 1,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
          ),
        ),
      );

      expect(find.text('Thắng 3 trận'), findsOneWidget);
      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.label, 'Nhận thưởng');
      expect(button.onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quest hoàn thành chưa claim: nút Nhận thưởng bật, bấm gọi đúng onClaim với đúng id',
    (tester) async {
      String? claimedId;
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 3,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (id) => claimedId = id,
          ),
        ),
      );

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.onTap, isNotNull);

      await tester.tap(find.byType(CommonButton));
      await tester.pump();

      expect(claimedId, 'win_3');
    },
  );

  testWidgets(
    'quest đã claim: nút hiện "Đã nhận", bị disable, bấm không gọi onClaim',
    (tester) async {
      var claimCount = 0;
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 3,
                target: 3,
                claimed: true,
              ),
            ],
            onClaim: (_) => claimCount++,
          ),
        ),
      );

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.label, 'Đã nhận');
      expect(button.onTap, isNull);

      await tester.tap(find.byType(CommonButton), warnIfMissed: false);
      await tester.pump();

      expect(claimCount, 0);
    },
  );

  testWidgets('nhiều quest hiển thị đúng thứ tự, mỗi cái claim độc lập', (
    tester,
  ) async {
    final claimedIds = <String>[];
    await tester.pumpWidget(
      host(
        QuestBoardPanel(
          quests: const [
            QuestViewModel(
              id: 'a',
              label: 'Quest A',
              progress: 3,
              target: 3,
              claimed: false,
            ),
            QuestViewModel(
              id: 'b',
              label: 'Quest B',
              progress: 1,
              target: 5,
              claimed: false,
            ),
          ],
          onClaim: claimedIds.add,
        ),
      ),
    );

    expect(find.text('Quest A'), findsOneWidget);
    expect(find.text('Quest B'), findsOneWidget);

    final buttons = tester.widgetList<CommonButton>(find.byType(CommonButton));
    expect(buttons.length, 2);

    await tester.tap(find.byType(CommonButton).first);
    await tester.pump();

    expect(claimedIds, ['a']);
  });

  testWidgets(
    'target = 0 không chia cho 0 / không crash (edge case phòng thủ)',
    (tester) async {
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'weird',
                label: 'Weird quest',
                progress: 0,
                target: 0,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quest CHUYỂN sang claimable lúc runtime (didUpdateWidget) trigger animation pop, không throw',
    (tester) async {
      var quests = const [
        QuestViewModel(
          id: 'win_3',
          label: 'Thắng 3 trận',
          progress: 2,
          target: 3,
          claimed: false,
        ),
      ];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            QuestBoardPanel(
              quests: quests,
              onClaim: (_) {},
            ),
          ),
        ),
      );

      final buttonBefore = tester.widget<CommonButton>(
        find.byType(CommonButton),
      );
      expect(buttonBefore.onTap, isNull);

      quests = const [
        QuestViewModel(
          id: 'win_3',
          label: 'Thắng 3 trận',
          progress: 3,
          target: 3,
          claimed: false,
        ),
      ];
      await tester.pumpWidget(
        host(QuestBoardPanel(quests: quests, onClaim: (_) {})),
      );
      await tester.pump();

      final buttonAfter = tester.widget<CommonButton>(
        find.byType(CommonButton),
      );
      expect(buttonAfter.onTap, isNotNull);
      expect(tester.takeException(), isNull);

      // Chạy hết animation, không còn Timer/Ticker treo.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quest ĐÃ claimable ngay từ lần mount đầu tiên không throw (không replay animation)',
    (tester) async {
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 3,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.onTap, isNotNull);
    },
  );

  testWidgets(
    'Reduce Motion bật: quest chuyển sang claimable không animate, vẫn đúng trạng thái nút',
    (tester) async {
      Widget hostReduced(Widget child) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: child)),
      );

      await tester.pumpWidget(
        hostReduced(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 2,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
          ),
        ),
      );

      await tester.pumpWidget(
        hostReduced(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 3,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-70: claiming', () {
    testWidgets(
      'quest.claiming: true truyền đúng xuống CommonButton của quest đó, hiện spinner',
      (tester) async {
        await tester.pumpWidget(
          host(
            QuestBoardPanel(
              quests: const [
                QuestViewModel(
                  id: 'win_3',
                  label: 'Thắng 3 trận',
                  progress: 3,
                  target: 3,
                  claimed: false,
                  claiming: true,
                ),
              ],
              onClaim: (_) {},
            ),
          ),
        );

        final button = tester.widget<CommonButton>(find.byType(CommonButton));
        expect(button.loading, isTrue);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'chỉ đúng quest đang claiming hiện spinner, quest khác trong cùng panel không bị ảnh hưởng',
      (tester) async {
        await tester.pumpWidget(
          host(
            QuestBoardPanel(
              quests: const [
                QuestViewModel(
                  id: 'a',
                  label: 'Quest A',
                  progress: 3,
                  target: 3,
                  claimed: false,
                  claiming: true,
                ),
                QuestViewModel(
                  id: 'b',
                  label: 'Quest B',
                  progress: 3,
                  target: 3,
                  claimed: false,
                  claiming: false,
                ),
              ],
              onClaim: (_) {},
            ),
          ),
        );

        final buttons = tester.widgetList<CommonButton>(
          find.byType(CommonButton),
        );
        expect(buttons.where((b) => b.loading).length, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('claiming: true chặn onClaim của đúng quest đó', (
      tester,
    ) async {
      var claimedId = '';
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 3,
                target: 3,
                claimed: false,
                claiming: true,
              ),
            ],
            onClaim: (id) => claimedId = id,
          ),
        ),
      );

      await tester.tap(find.byType(CommonButton));
      await tester.pump();

      expect(claimedId, isEmpty);
    });

    testWidgets('claiming: false (mặc định) hành vi y hệt trước đây', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'win_3',
                label: 'Thắng 3 trận',
                progress: 3,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.loading, isFalse);
    });
  });

  group('ENH-75: caller-overridable copy', () {
    testWidgets('không truyền param mới: hiển thị y hệt hiện tại', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(QuestBoardPanel(quests: const [], onClaim: (_) {})),
      );

      expect(find.text('Không có nhiệm vụ nào hôm nay.'), findsOneWidget);
    });

    testWidgets('emptyMessage tuỳ chỉnh hiển thị đúng khi danh sách rỗng', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [],
            onClaim: (_) {},
            emptyMessage: 'Custom empty',
          ),
        ),
      );

      expect(find.text('Custom empty'), findsOneWidget);
      expect(find.text('Không có nhiệm vụ nào hôm nay.'), findsNothing);
    });

    testWidgets('claimLabel/claimedLabel tuỳ chỉnh đổi đúng label nút theo claimed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'a',
                label: 'Quest A',
                progress: 3,
                target: 3,
                claimed: false,
              ),
            ],
            onClaim: (_) {},
            claimLabel: 'Claim',
            claimedLabel: 'Claimed',
          ),
        ),
      );

      var button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.label, 'Claim');

      await tester.pumpWidget(
        host(
          QuestBoardPanel(
            quests: const [
              QuestViewModel(
                id: 'a',
                label: 'Quest A',
                progress: 3,
                target: 3,
                claimed: true,
              ),
            ],
            onClaim: (_) {},
            claimLabel: 'Claim',
            claimedLabel: 'Claimed',
          ),
        ),
      );
      await tester.pump();

      button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.label, 'Claimed');
    });

    testWidgets(
      'progressSemanticLabel tuỳ chỉnh dùng đúng kết quả callback thay vì chuỗi mặc định',
      (tester) async {
        await tester.pumpWidget(
          host(
            QuestBoardPanel(
              quests: const [
                QuestViewModel(
                  id: 'a',
                  label: 'Quest A',
                  progress: 1,
                  target: 3,
                  claimed: false,
                ),
              ],
              onClaim: (_) {},
              progressSemanticLabel: (q) => 'Custom: ${q.progress}/${q.target}',
            ),
          ),
        );

        final bar = tester.widget<ProgressBarStars>(
          find.byType(ProgressBarStars),
        );
        expect(bar.semanticLabel, 'Custom: 1/3');
      },
    );
  });
}
