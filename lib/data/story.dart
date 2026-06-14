import 'levels.dart';

/// Thời điểm kích hoạt 1 đoạn cốt truyện.
/// - intro: lần đầu bước vào thế giới (màn đầu của world)
/// - mid: tới mốc giữa thế giới (màn thứ 10 của world)
/// - outro: vừa thắng màn cuối của thế giới
enum StoryTrigger { intro, mid, outro }

/// Một "beat" cốt truyện: lời thoại của vệ thần neon ở 1 thế giới.
/// Nội dung text nằm trong i18n (key suy ra từ [id]); class chỉ giữ metadata.
class StoryBeat {
  final String id; // ví dụ 'w1_intro'
  final int world; // 1..5
  final StoryTrigger trigger;
  final int npc; // chỉ số nhân vật (= world)
  final int lineCount; // số dòng thoại

  const StoryBeat({
    required this.id,
    required this.world,
    required this.trigger,
    required this.npc,
    this.lineCount = 2,
  });

  String get titleKey => 'story_${id}_title';
  String get npcNameKey => 'npc_name_$npc';
  String lineKey(int i) => 'story_${id}_l${i + 1}';
}

/// Toàn bộ beat: 5 thế giới × 3 thời điểm = 15 beat (mỗi beat 2 dòng).
final List<StoryBeat> kStory = [
  for (final w in kWorlds)
    for (final t in StoryTrigger.values)
      StoryBeat(id: 'w${w.index}_${t.name}', world: w.index, trigger: t, npc: w.index),
];

/// Tìm beat theo [trigger] + [world]. Null nếu không có.
StoryBeat? storyBeatFor(StoryTrigger trigger, int world) {
  for (final b in kStory) {
    if (b.trigger == trigger && b.world == world) return b;
  }
  return null;
}

/// Trigger cốt truyện khi BẮT ĐẦU [level] (intro/mid), null nếu không có.
StoryTrigger? storyStartTriggerFor(int level) {
  final w = worldOfLevel(level);
  if (level == w.startLevel) return StoryTrigger.intro;
  if (level == w.startLevel + (kWorldSize ~/ 2)) return StoryTrigger.mid;
  return null;
}
