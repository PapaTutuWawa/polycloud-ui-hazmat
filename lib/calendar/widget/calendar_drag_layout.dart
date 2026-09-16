import 'dart:math' as math;
import 'dart:ui';

import 'package:polycloud_ui_hazmat/calendar/models/calendar_event.dart';
import 'package:polycloud_ui_hazmat/calendar/widget/calendar_event_layout.dart';

CalendarEvent? timedDragEvent({
  required Offset anchor,
  required Offset current,
  required List<DateTime> days,
  required double columnWidth,
  required double bodyHeight,
  required int cellCount,
  required Duration dayStart,
  required Duration dayEnd,
  required Duration increment,
}) {
  if (days.isEmpty || columnWidth <= 0 || bodyHeight <= 0) {
    return null;
  }

  final anchorCell = _cellAt(anchor.dy, bodyHeight, cellCount);
  final currentCell = _cellAt(current.dy, bodyHeight, cellCount);
  var topCell = math.min(anchorCell, currentCell).floor();
  var bottomCell = math.max(anchorCell, currentCell).ceil();
  if (bottomCell <= topCell) {
    bottomCell = topCell + 1;
  }
  topCell = topCell < 0 ? 0 : (topCell > cellCount ? cellCount : topCell);
  bottomCell =
      bottomCell < 0 ? 0 : (bottomCell > cellCount ? cellCount : bottomCell);

  var leftColumn = (math.min(anchor.dx, current.dx) / columnWidth).floor();
  var rightColumn = (math.max(anchor.dx, current.dx) / columnWidth).floor();
  leftColumn = leftColumn < 0
      ? 0
      : (leftColumn > days.length - 1 ? days.length - 1 : leftColumn);
  rightColumn = rightColumn < 0
      ? 0
      : (rightColumn > days.length - 1 ? days.length - 1 : rightColumn);

  final start = _midnight(days[leftColumn]).add(dayStart + increment * topCell);
  final end = _midnight(days[rightColumn]).add(dayStart + increment * bottomCell);
  final rangeEnd = _midnight(days[rightColumn]).add(dayEnd);
  return CalendarEvent(
    title: '',
    start: start,
    end: end.isAfter(rangeEnd) ? rangeEnd : end,
  );
}

CalendarEvent? allDayDragEvent({
  required Offset anchor,
  required Offset current,
  required List<DateTime> days,
  required double columnWidth,
}) {
  if (days.isEmpty || columnWidth <= 0) {
    return null;
  }

  var left = (math.min(anchor.dx, current.dx) / columnWidth).floor();
  var right = (math.max(anchor.dx, current.dx) / columnWidth).floor();
  left = left < 0 ? 0 : (left > days.length - 1 ? days.length - 1 : left);
  right = right < 0 ? 0 : (right > days.length - 1 ? days.length - 1 : right);

  final start = _midnight(days[left]);
  final end = _midnight(days[right]).add(const Duration(days: 1));
  return CalendarEvent(title: '', start: start, end: end, allDay: true);
}

bool isTimeOccupied({
  required List<CalendarEvent> events,
  required DateTime day,
  required Duration dayStart,
  required Duration dayEnd,
  required DateTime at,
}) {
  final laidOut = layoutDayEvents(
    events: events,
    day: day,
    dayStart: dayStart,
    dayEnd: dayEnd,
  );
  for (final item in laidOut) {
    if (!at.isBefore(item.start) && at.isBefore(item.end)) {
      return true;
    }
  }
  return false;
}

DateTime dayAt(List<DateTime> days, double dx, double columnWidth) {
  var column = columnWidth <= 0 ? 0 : (dx / columnWidth).floor();
  column =
      column < 0 ? 0 : (column > days.length - 1 ? days.length - 1 : column);
  return _midnight(days[column]);
}

double _cellAt(double dy, double bodyHeight, int cellCount) =>
    (dy / bodyHeight) * cellCount;

DateTime _midnight(DateTime day) => DateTime(day.year, day.month, day.day);
