/// Clan/Friends offline (Wave 23) — "biệt đội" gồm người chơi + bot AI có đóng góp
/// hằng TUẦN TẤT ĐỊNH (no Random, mirror style hash của tournament/leaderboard).
/// Cả clan góp điểm → đạt mục tiêu tuần thì mở thưởng (1 lần/tuần). Pure Dart.
library;

/// Tên thành viên bot (proper noun — KHÔNG dịch). ≥ kClanBotCount để không trùng.
const List<String> kClanMemberNames = [
  'Blaze',
  'Pulse',
  'Vega',
  'Zenith',
  'Comet',
  'Drift',
  'Halo',
  'Specter',
  'Apex',
  'Rune',
  'Cobalt',
  'Ember',
];

/// Số thành viên bot (clan = bot + người chơi).
const int kClanBotCount = 9;

/// Mục tiêu đóng góp tuần của cả clan để mở thưởng.
const int kClanWeeklyGoal = 900;

/// Thưởng xu khi clan đạt mục tiêu tuần (1 lần/tuần).
const int kClanWeeklyReward = 250;

/// Điểm đóng góp khi NGƯỜI CHƠI thắng 1 màn (theo sao).
int clanPointsForWin(int stars) => 8 + stars * 4;

/// W24.4 — Điểm đóng góp khi thắng 1 ván SIDE-MODE bất kỳ (không có sao) — cố định,
/// thấp hơn campaign (khuyến khích campaign vẫn là nguồn chính, side-mode chỉ bù thêm).
const int kClanPointsForSideModeWin = 10;

/// 1 thành viên clan trên bảng đóng góp tuần.
class ClanMember {
  final String name;
  final int contribution;
  final bool isPlayer;
  const ClanMember(this.name, this.contribution, {this.isPlayer = false});
}

/// Đóng góp tuần [week] của bot [rank] (0-based) — TẤT ĐỊNH (no Random).
int clanBotContribution(int week, int rank) {
  final mix = (week * 2654435761 + rank * 40503 + 777) & 0x7fffffff;
  return 40 + (mix % 121); // 40..160 / bot / tuần
}

/// Tên bot [rank] cho [week] — distinct trong cùng clan (rank < pool size).
String clanBotName(int rank, int week) {
  final start = (week * 17) & 0x7fffffff;
  return kClanMemberNames[(start + rank) % kClanMemberNames.length];
}

/// Bảng đóng góp clan (giảm dần): 9 bot + người chơi. Tie: người chơi xếp trên.
List<ClanMember> buildClanRoster(int playerContribution, int week) {
  assert(
    kClanBotCount <= kClanMemberNames.length,
    'kClanBotCount phải <= số tên bot để không trùng',
  );
  final list = <ClanMember>[
    for (var r = 0; r < kClanBotCount; r++)
      ClanMember(clanBotName(r, week), clanBotContribution(week, r)),
    ClanMember('', playerContribution.clamp(0, 1 << 30), isPlayer: true),
  ];
  list.sort((a, b) {
    final c = b.contribution.compareTo(a.contribution);
    if (c != 0) return c;
    if (a.isPlayer) return -1;
    if (b.isPlayer) return 1;
    return 0;
  });
  return list;
}

/// Tổng đóng góp của cả clan.
int clanTotal(List<ClanMember> roster) =>
    roster.fold(0, (s, m) => s + m.contribution);

/// Hạng (1-based) của người chơi trong clan; 0 nếu không có.
int clanPlayerRank(List<ClanMember> roster) {
  for (var i = 0; i < roster.length; i++) {
    if (roster[i].isPlayer) return i + 1;
  }
  return 0;
}

// ===== W23 (sâu hơn) — Clan vs Clan: BXH giữa clan người chơi + clan bot =====

/// Tên clan đối thủ (proper noun — KHÔNG dịch).
const List<String> kRivalClanNames = [
  'Void Kings',
  'Prism Pack',
  'Hex Legion',
  'Lumen Guild',
  'Pulse Crew',
];

/// Thưởng xu theo HẠNG clan cuối tuần (1-based): top 1/2/3; ngoài top 3 → 0.
int clanLeagueRewardFor(int rank) {
  switch (rank) {
    case 1:
      return 300;
    case 2:
      return 200;
    case 3:
      return 100;
    default:
      return 0;
  }
}

/// 1 dòng BXH Clan.
class ClanStanding {
  final String name;
  final int total;
  final bool isYou; // clan của người chơi
  const ClanStanding(this.name, this.total, {this.isYou = false});
}

/// Tổng đóng góp tuần [week] của clan đối thủ [idx] — TẤT ĐỊNH (no Random).
int rivalClanTotal(int week, int idx) {
  final mix = (week * 2654435761 + idx * 97 + 555) & 0x7fffffff;
  return 500 + (mix % 900); // 500..1399 / tuần
}

/// BXH Clan (giảm dần): clan đối thủ + clan người chơi ([playerClanTotal]).
/// Tie: clan người chơi xếp trên.
List<ClanStanding> buildClanLeague(int playerClanTotal, int week) {
  final list = <ClanStanding>[
    for (var i = 0; i < kRivalClanNames.length; i++)
      ClanStanding(kRivalClanNames[i], rivalClanTotal(week, i)),
    ClanStanding('', playerClanTotal.clamp(0, 1 << 30), isYou: true),
  ];
  list.sort((a, b) {
    final c = b.total.compareTo(a.total);
    if (c != 0) return c;
    if (a.isYou) return -1;
    if (b.isYou) return 1;
    return 0;
  });
  return list;
}

/// Hạng (1-based) clan người chơi trong BXH Clan; 0 nếu không có.
int clanLeagueRank(List<ClanStanding> league) {
  for (var i = 0; i < league.length; i++) {
    if (league[i].isYou) return i + 1;
  }
  return 0;
}
