import 'package:dingdong/core/models/date_filter_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar presets handle month/year boundaries and Monday weeks', () {
    final now = DateTime(2026, 1, 1, 23, 59);
    final yesterday = DateFilterPreset.yesterday.bounds(now)!;
    expect(yesterday.start, DateTime(2025, 12, 31));
    expect(yesterday.end, DateTime(2025, 12, 31));
    expect(
      DateFilterPreset.lastThreeDays.bounds(now)!.start,
      DateTime(2025, 12, 30),
    );
    expect(
      DateFilterPreset.thisWeek.bounds(now)!.start,
      DateTime(2025, 12, 29),
    );
    final month = DateFilterPreset.lastMonth.bounds(now)!;
    expect(month.start, DateTime(2025, 12));
    expect(month.end, DateTime(2025, 12, 31));
    expect(
      DateFilterPreset.lastThreeMonths.bounds(now)!.start,
      DateTime(2025, 11),
    );
    expect(DateFilterPreset.thisYear.bounds(now)!.start, DateTime(2026));
    expect(DateFilterPreset.custom.bounds(now), isNull);
  });
  test('inclusive local date bounds include an entire final day', () {
    final range = DateFilterPreset.yesterday.bounds(DateTime(2026, 3, 2))!;
    expect(dateWithinFilter(DateTime(2026, 3, 1, 23, 59, 59), range), isTrue);
    expect(dateWithinFilter(DateTime(2026, 3, 2), range), isFalse);
  });
}
