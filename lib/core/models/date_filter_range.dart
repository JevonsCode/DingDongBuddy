import 'package:flutter/material.dart';

/// Inclusive local calendar dates, shared by activity and token history.
enum DateFilterPreset {
  yesterday,
  lastThreeDays,
  thisWeek,
  thisMonth,
  lastMonth,
  lastThreeMonths,
  thisYear,
  custom;

  DateTimeRange? bounds(DateTime now) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final start = switch (this) {
      yesterday => DateTime(today.year, today.month, today.day - 1),
      lastThreeDays => DateTime(today.year, today.month, today.day - 2),
      thisWeek => DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1,
      ),
      thisMonth => DateTime(today.year, today.month),
      lastMonth => DateTime(today.year, today.month - 1),
      lastThreeMonths => DateTime(today.year, today.month - 2),
      thisYear => DateTime(today.year),
      custom => null,
    };
    if (start == null) return null;
    final end = switch (this) {
      yesterday => start,
      lastMonth => DateTime(today.year, today.month, 0),
      _ => today,
    };
    return DateTimeRange(start: start, end: end);
  }
}

bool dateWithinFilter(DateTime value, DateTimeRange? range) {
  if (range == null) return true;
  final local = value.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return !day.isBefore(range.start) && !day.isAfter(range.end);
}
