import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formats clipboard timestamps for fast scanning without repeating today.
String clipboardTimestampLabel(
  BuildContext context,
  DateTime timestamp, {
  DateTime? now,
}) {
  final DateTime localTimestamp = timestamp.toLocal();
  final DateTime localNow = (now ?? DateTime.now()).toLocal();
  final bool isToday =
      localTimestamp.year == localNow.year &&
      localTimestamp.month == localNow.month &&
      localTimestamp.day == localNow.day;
  if (isToday) {
    return TimeOfDay.fromDateTime(localTimestamp).format(context);
  }

  final String locale = Localizations.localeOf(context).toLanguageTag();
  if (localTimestamp.year == localNow.year) {
    return DateFormat.MMMd(locale).format(localTimestamp);
  }
  return DateFormat.yMMMd(locale).format(localTimestamp);
}
