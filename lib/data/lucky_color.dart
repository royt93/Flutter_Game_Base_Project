import 'dart:math';

int luckyColorIndexForDay(int epochDay, int colorCount) =>
    Random(epochDay).nextInt(colorCount);
