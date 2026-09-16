import 'package:polycloud_ui_hazmat/calendar/models/calendar_event.dart';

class LaidOutAllDayEvent {
  const LaidOutAllDayEvent({
    required this.event,
    required this.startIndex,
    required this.endIndex,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEvent event;

  final int startIndex;

  final int endIndex;

  final int lane;

  final int laneCount;
}

class _AllDaySegment {
  const _AllDaySegment(this.event, this.startIndex, this.endIndex);

  final CalendarEvent event;

  final int startIndex;

  final int endIndex;
}

List<LaidOutAllDayEvent> layoutAllDayEvents({
  required List<CalendarEvent> events,
  required List<DateTime> days,
}) {
  if (days.isEmpty) {
    return const [];
  }

  final segments = <_AllDaySegment>[];
  for (final event in events) {
    final startIndex = _indexOfDay(days, event.localStart);
    final endExclusive = _endExclusive(event);
    final endIndex = _indexOfDay(days, endExclusive);

    final resolvedStart = startIndex ??
        (event.localStart.isBefore(days.first) ? 0 : null);
    final resolvedEnd =
        endIndex ?? (endExclusive.isAfter(days.last) ? days.length : null);

    if (resolvedStart == null || resolvedEnd == null) {
      continue;
    }
    if (resolvedStart >= resolvedEnd) {
      continue;
    }
    segments.add(_AllDaySegment(event, resolvedStart, resolvedEnd));
  }

  segments.sort((a, b) {
    final byStart = a.startIndex.compareTo(b.startIndex);
    if (byStart != 0) {
      return byStart;
    }
    return a.endIndex.compareTo(b.endIndex);
  });

  final laneEnds = <int>[];
  final lanes = <int>[];
  for (final segment in segments) {
    var lane = laneEnds.indexWhere((end) => end <= segment.startIndex);
    if (lane == -1) {
      laneEnds.add(segment.endIndex);
      lane = laneEnds.length - 1;
    } else {
      laneEnds[lane] = segment.endIndex;
    }
    lanes.add(lane);
  }

  final laneCount = laneEnds.length;
  return [
    for (var index = 0; index < segments.length; index++)
      LaidOutAllDayEvent(
        event: segments[index].event,
        startIndex: segments[index].startIndex,
        endIndex: segments[index].endIndex,
        lane: lanes[index],
        laneCount: laneCount,
      ),
  ];
}

int? _indexOfDay(List<DateTime> days, DateTime time) {
  for (var index = 0; index < days.length; index++) {
    final day = days[index];
    if (day.year == time.year && day.month == time.month && day.day == time.day) {
      return index;
    }
  }
  return null;
}

DateTime _endExclusive(CalendarEvent event) {
  final start = event.localStart;
  final end = event.localEnd;
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(end.year, end.month, end.day);
  final isMidnight = end.hour == 0 &&
      end.minute == 0 &&
      end.second == 0 &&
      end.millisecond == 0 &&
      end.microsecond == 0;
  if (isMidnight && endDate.isAfter(startDate)) {
    return endDate;
  }
  return endDate.add(const Duration(days: 1));
}
