enum DayColor { green, red, gray }

class DaySummary {
  DaySummary({
    required this.dateIso,
    required this.color,
    required this.doneCount,
    required this.notDoneCount,
    required this.totalCount,
  });

  final String dateIso; // yyyy-MM-dd
  final DayColor color;
  final int doneCount;
  final int notDoneCount;
  final int totalCount;
}

class ProgressStats {
  ProgressStats({
    required this.greenDays,
    required this.totalDays,
    required this.completionPercent,
    required this.currentStreak,
  });

  final int greenDays;
  final int totalDays;
  final double completionPercent; // 0..1
  final int currentStreak;
}

