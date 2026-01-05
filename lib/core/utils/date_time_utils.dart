import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// All persisted day-only dates are ISO `yyyy-MM-dd`.
final DateFormat kIsoDate = DateFormat('yyyy-MM-dd');

/// All persisted time-only values are `HH:mm` (24h).
final DateFormat kIsoTime = DateFormat('HH:mm');

extension DateOnlyX on DateTime {
  DateTime toDateOnly() => DateTime(year, month, day);
  String toIsoDate() => kIsoDate.format(this);
}

DateTime parseIsoDate(String iso) => kIsoDate.parseStrict(iso).toDateOnly();

String? timeOfDayToIso(TimeOfDay? tod) {
  if (tod == null) return null;
  final hh = tod.hour.toString().padLeft(2, '0');
  final mm = tod.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

TimeOfDay? isoToTimeOfDay(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final parts = iso.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

String formatFriendlyDate(DateTime date) => DateFormat.yMMMEd().format(date);

