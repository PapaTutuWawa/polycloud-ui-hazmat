import 'package:polycloud_ui_hazmat/calendar/models/calendar_event.dart';

class LaidOutEvent {
  const LaidOutEvent({
    required this.event,
    required this.start,
    required this.end,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEvent event;

  final DateTime start;

  final DateTime end;

  final int lane;

  final int laneCount;
}

class _Segment {
  const _Segment(this.event, this.start, this.end);

  final CalendarEvent event;

  final DateTime start;

  final DateTime end;
}

List<LaidOutEvent> layoutDayEvents({
  required List<CalendarEvent> events,
  required DateTime day,
  required Duration dayStart,
  required Duration dayEnd,
}) {
  final midnight = DateTime(day.year, day.month, day.day);
  final rangeStart = midnight.add(dayStart);
  final rangeEnd = midnight.add(dayEnd);

  final segments = <_Segment>[];
  for (final event in events) {
    final start =
        event.localStart.isAfter(rangeStart) ? event.localStart : rangeStart;
    final end = event.localEnd.isBefore(rangeEnd) ? event.localEnd : rangeEnd;
    if (!end.isAfter(start)) {
      continue;
    }
    segments.add(_Segment(event, start, end));
  }

  segments.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) {
      return byStart;
    }
    return b.end.compareTo(a.end);
  });

  final result = <LaidOutEvent>[];
  var cluster = <_Segment>[];
  DateTime? clusterEnd;

  void flush() {
    if (cluster.isEmpty) {
      return;
    }
    final laneEnds = <DateTime>[];
    final lanes = <int>[];
    for (final segment in cluster) {
      var lane = laneEnds.indexWhere((end) => !end.isAfter(segment.start));
      if (lane == -1) {
        laneEnds.add(segment.end);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = segment.end;
      }
      lanes.add(lane);
    }
    final laneCount = laneEnds.length;
    for (var i = 0; i < cluster.length; i++) {
      result.add(LaidOutEvent(
        event: cluster[i].event,
        start: cluster[i].start,
        end: cluster[i].end,
        lane: lanes[i],
        laneCount: laneCount,
      ));
    }
    cluster = <_Segment>[];
    clusterEnd = null;
  }

  for (final segment in segments) {
    if (clusterEnd != null && segment.start.isAfter(clusterEnd!)) {
      flush();
    }
    cluster.add(segment);
    if (clusterEnd == null || segment.end.isAfter(clusterEnd!)) {
      clusterEnd = segment.end;
    }
  }
  flush();

  return result;
}
