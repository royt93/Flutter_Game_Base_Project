enum BurstStyleKind { spark, confetti, ripple, starburst }

class BurstStyle {
  const BurstStyle({
    required this.kind,
    required this.nameKey,
    required this.unlockThreshold,
  });

  final BurstStyleKind kind;
  final String nameKey;
  final int unlockThreshold;
}

const List<BurstStyle> kBurstStyles = [
  BurstStyle(
    kind: BurstStyleKind.spark,
    nameKey: 'burst_style_spark',
    unlockThreshold: 0,
  ),
  BurstStyle(
    kind: BurstStyleKind.confetti,
    nameKey: 'burst_style_confetti',
    unlockThreshold: 500,
  ),
  BurstStyle(
    kind: BurstStyleKind.ripple,
    nameKey: 'burst_style_ripple',
    unlockThreshold: 2000,
  ),
  BurstStyle(
    kind: BurstStyleKind.starburst,
    nameKey: 'burst_style_starburst',
    unlockThreshold: 5000,
  ),
];

bool isBurstStyleUnlocked(BurstStyle style, int totalGemsPopped) =>
    totalGemsPopped >= style.unlockThreshold;
